import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import basicSsl from '@vitejs/plugin-basic-ssl'
import fs from 'node:fs'
import path from 'node:path'

// Dev-only helper: lets automated checks save an exported file to disk so it can be inspected with ffprobe.
// Active only when CM_SAVE_DIR is set. Never part of the production build.
function devSave() {
  return {
    name: 'cm-dev-save',
    apply: 'serve' as const,
    configureServer(server: import('vite').ViteDevServer) {
      const dir = process.env.CM_SAVE_DIR
      if (!dir) return
      server.middlewares.use('/__save', (req, res) => {
        const name = path.basename(String(new URL(req.url ?? '', 'http://x').searchParams.get('name') ?? 'out.bin'))
        const chunks: Buffer[] = []
        req.on('data', (c) => chunks.push(c))
        req.on('end', () => {
          fs.mkdirSync(dir, { recursive: true })
          fs.writeFileSync(path.join(dir, name), Buffer.concat(chunks))
          res.end('ok')
        })
      })
    },
  }
}

export default defineConfig({
  // CM_HTTPS=1 serves over HTTPS with a self-signed certificate. Phones on the same Wi-Fi need it: video encoding,
  // the share sheet and wake lock only work on secure pages, and plain http://192.168.x.x is not one.
  plugins: [react(), devSave(), ...(process.env.CM_HTTPS ? [basicSsl()] : [])],
  build: {
    target: 'es2022',
    sourcemap: false,
    chunkSizeWarningLimit: 700,
    rollupOptions: {
      output: {
        // Video library in its own file so it is cached separately from the app code.
        manualChunks: (id: string) => (id.includes('node_modules/mediabunny') ? 'video-engine' : undefined),
      },
    },
  },
  test: { environment: 'node', include: ['src/**/*.test.ts'] },
})
