import type { Layout, Rect } from './types'

const equalParts = (n: number) => Array.from({ length: n }, () => 1 / n)

/** Rows stacked top to bottom; row i holds counts[i] equal-width cells. */
function rowsOf(counts: number[], heights: number[] = equalParts(counts.length)): Rect[] {
  const rects: Rect[] = []
  let y = 0
  counts.forEach((n, i) => {
    for (let c = 0; c < n; c++) rects.push([c / n, y, 1 / n, heights[i]])
    y += heights[i]
  })
  return rects
}

/** Columns side by side; column i holds counts[i] equal-height cells. */
function colsOf(counts: number[], widths: number[] = equalParts(counts.length)): Rect[] {
  const rects: Rect[] = []
  let x = 0
  counts.forEach((n, i) => {
    for (let r = 0; r < n; r++) rects.push([x, r / n, widths[i], 1 / n])
    x += widths[i]
  })
  return rects
}

const L = (id: string, name: string, rects: Rect[]): Layout => ({ id, name, count: rects.length, rects })

export const LAYOUTS: Layout[] = [
  L('1-full', 'Full', rowsOf([1])),
  L('1-centre', 'Centred', [[0.08, 0.2, 0.84, 0.6]]),

  L('2-stack', 'Stacked', rowsOf([1, 1])),
  L('2-side', 'Side by side', colsOf([1, 1])),
  L('2-top-small', 'Small on top', rowsOf([1, 1], [1 / 3, 2 / 3])),
  L('2-top-big', 'Big on top', rowsOf([1, 1], [2 / 3, 1 / 3])),
  L('2-left-small', 'Small on left', colsOf([1, 1], [1 / 3, 2 / 3])),

  L('3-rows', 'Three rows', rowsOf([1, 1, 1])),
  L('3-cols', 'Three columns', colsOf([1, 1, 1])),
  L('3-big-top', 'Big on top', rowsOf([1, 2], [0.6, 0.4])),
  L('3-big-bottom', 'Big at bottom', rowsOf([2, 1], [0.4, 0.6])),
  L('3-big-left', 'Big on left', colsOf([1, 2], [0.6, 0.4])),
  L('3-big-right', 'Big on right', colsOf([2, 1], [0.4, 0.6])),

  L('4-grid', 'Grid', rowsOf([2, 2])),
  L('4-big-top', 'Big on top', rowsOf([1, 3], [0.55, 0.45])),
  L('4-big-bottom', 'Big at bottom', rowsOf([3, 1], [0.45, 0.55])),
  L('4-band', 'Middle pair', rowsOf([1, 2, 1], [0.35, 0.3, 0.35])),
  L('4-side', 'Big and stack', colsOf([1, 3], [0.5, 0.5])),

  L('5-hero', 'Hero and four', rowsOf([1, 2, 2], [0.4, 0.3, 0.3])),
  L('5-two-three', 'Two and three', rowsOf([2, 3])),
  L('5-three-two', 'Three and two', rowsOf([3, 2])),
  L('5-sandwich', 'Sandwich', rowsOf([2, 1, 2], [0.3, 0.4, 0.3])),

  L('6-grid', 'Grid 2×3', rowsOf([2, 2, 2])),
  L('6-wide', 'Grid 3×2', rowsOf([3, 3])),
  L('6-stairs', 'Stairs', rowsOf([1, 2, 3], [0.4, 0.3, 0.3])),
  L('6-mix', 'Wide and pairs', rowsOf([1, 1, 2, 2], [0.28, 0.28, 0.22, 0.22])),

  L('7-hero', 'Hero and six', rowsOf([1, 3, 3], [0.4, 0.3, 0.3])),
  L('7-three-four', 'Three and four', rowsOf([3, 4])),
  L('7-mix', 'Mixed rows', rowsOf([2, 2, 3])),

  L('8-grid', 'Grid 2×4', rowsOf([2, 2, 2, 2])),
  L('8-wide', 'Grid 4×2', rowsOf([4, 4])),
  L('8-mix', 'Mixed rows', rowsOf([2, 3, 3])),

  L('9-grid', 'Grid 3×3', rowsOf([3, 3, 3])),
  L('9-hero', 'Hero and eight', rowsOf([1, 4, 4], [0.36, 0.32, 0.32])),
  L('9-pyramid', 'Pyramid', rowsOf([2, 3, 4])),
]

export const MAX_CELLS = 9
export const MAX_VIDEOS = 2

export const layoutsFor = (count: number): Layout[] => LAYOUTS.filter((l) => l.count === count)

export const layoutById = (id: string): Layout => LAYOUTS.find((l) => l.id === id) ?? LAYOUTS[0]

export const defaultLayoutFor = (count: number): Layout => layoutsFor(count)[0] ?? LAYOUTS[0]
