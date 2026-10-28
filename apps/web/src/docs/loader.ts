/**
 * The docs content model.
 *
 * Every markdown file under /docs is a candidate. A file is published only when it
 * opens with frontmatter carrying a `title`, so internal notes can sit in the same
 * tree without leaking onto the public page (docs/clerk-troubleshooting.md is the
 * existing example: no frontmatter, not published).
 *
 * Frontmatter is a flat `key: value` block. That is the whole format — no nested
 * maps, no lists, no dependency on a YAML parser.
 *
 * Nesting comes from the filesystem, not from a field: `loops/index.md` is the
 * parent and anything in `loops/` is its child. A file and a directory of the same
 * name would be confusing to keep, and a `parent:` field would let the two drift.
 */

export type Doc = {
  slug: string
  title: string
  group: string
  summary: string
  order: number
  body: string
  /** Slugs this page points at, from the flat `related:` frontmatter list. */
  related: string[]
  /** Free-form build status, shown as a chip. Used by the loop catalogue. */
  status?: string
}

/** A page in the rail: the page itself, plus any pages nested under it. */
export type DocEntry = { doc: Doc; children: Doc[] }

export type DocGroup = { label: string; entries: DocEntry[] }

/** One entry in an article's "On this page" rail. */
export type Heading = { id: string; text: string; depth: 2 | 3 }

/** The order groups appear in the rail. An unlisted group sorts after these, by name. */
const GROUP_ORDER = ['Concepts', 'Architecture', 'Guides']
const DEFAULT_GROUP = 'Guides'

const sources = import.meta.glob('/docs/**/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>

function splitFrontmatter(source: string): { fields: Record<string, string>; body: string } {
  const match = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*\r?\n?/.exec(source)
  if (!match) return { fields: {}, body: source }
  const fields: Record<string, string> = {}
  for (const line of match[1].split(/\r?\n/)) {
    const at = line.indexOf(':')
    if (at < 1) continue
    fields[line.slice(0, at).trim()] = line.slice(at + 1).trim().replace(/^["']|["']$/g, '')
  }
  return { fields, body: source.slice(match[0].length) }
}

/** `concepts/loops/index.md` publishes at `concepts/loops`, like a web server would. */
function slugOf(path: string): string {
  return path.replace(/^\/docs\//, '').replace(/\.md$/, '').replace(/\/index$/, '')
}

function toDoc(path: string, source: string): Doc | null {
  const { fields, body } = splitFrontmatter(source)
  if (!fields.title) return null
  return {
    slug: slugOf(path),
    title: fields.title,
    group: fields.group || DEFAULT_GROUP,
    summary: fields.summary || '',
    order: Number(fields.order) || 0,
    status: fields.status || undefined,
    related: (fields.related ?? '')
      .split(',')
      .map((slug) => slug.trim())
      .filter(Boolean),
    // The title lives in frontmatter, so a leading `# Title` in the body is a
    // duplicate heading. Authors can leave it in for a readable raw file.
    // `#\s` and not `#` so a leading `## Section` is left alone.
    body: body.replace(/^\s*#\s+[^\n]*\n+/, ''),
  }
}

function groupRank(group: string): number {
  const at = GROUP_ORDER.indexOf(group)
  return at === -1 ? GROUP_ORDER.length : at
}

const byOrder = (a: Doc, b: Doc) => a.order - b.order || a.title.localeCompare(b.title)

const published = Object.entries(sources)
  .map(([path, source]) => toDoc(path, source))
  .filter((doc): doc is Doc => doc !== null)

const bySlug = new Map(published.map((doc) => [doc.slug, doc]))

/**
 * A page's parent is the longest slug prefix that is itself a published page, so a
 * directory without an `index.md` is just a naming convention and not a broken link.
 */
function parentOf(slug: string): string | undefined {
  const parts = slug.split('/')
  for (let at = parts.length - 1; at > 0; at--) {
    const candidate = parts.slice(0, at).join('/')
    if (bySlug.has(candidate)) return candidate
  }
  return undefined
}

const parentBySlug = new Map<string, string>()
for (const doc of published) {
  const parent = parentOf(doc.slug)
  if (parent) parentBySlug.set(doc.slug, parent)
}

/**
 * The rail, in reading order: each page at its group position, its children directly
 * after it sorted among themselves. Nesting is expressed once, here, and everything
 * downstream (flat order, prev/next) is derived from it.
 */
export const DOC_GROUPS: DocGroup[] = (() => {
  const top = published.filter((doc) => !parentBySlug.has(doc.slug)).sort(
    (a, b) => groupRank(a.group) - groupRank(b.group) || byOrder(a, b),
  )
  const childrenOf = new Map<string, Doc[]>()
  for (const doc of published) {
    const parent = parentBySlug.get(doc.slug)
    if (!parent) continue
    const list = childrenOf.get(parent) ?? []
    list.push(doc)
    childrenOf.set(parent, list)
  }

  const groups: DocGroup[] = []
  for (const doc of top) {
    const children = (childrenOf.get(doc.slug) ?? []).sort(byOrder)
    const entry: DocEntry = { doc, children }
    const last = groups[groups.length - 1]
    if (last?.label === doc.group) last.entries.push(entry)
    else groups.push({ label: doc.group, entries: [entry] })
  }
  return groups
})()

/** Every published page in reading order, children inline after their parent. */
export const DOCS: Doc[] = DOC_GROUPS.flatMap((group) =>
  group.entries.flatMap((entry) => [entry.doc, ...entry.children]),
)

export function findDoc(slug: string | undefined): Doc | undefined {
  return published.find((doc) => doc.slug === slug)
}

/** The pages nested directly under this one. */
export function childrenOf(slug: string): Doc[] {
  return DOC_GROUPS.flatMap((group) => group.entries).find((entry) => entry.doc.slug === slug)?.children ?? []
}

/** The page this one is nested under, if any. */
export function parentOfSlug(slug: string): Doc | undefined {
  const parent = parentBySlug.get(slug)
  return parent ? bySlug.get(parent) : undefined
}

/**
 * The page before and after in reading order, for the article footer. Because DOCS
 * puts children directly after their parent, this walks out of a family and into the
 * next section on its own, which is what a reader expects at the end of a chapter.
 */
export function neighbours(slug: string): { prev?: Doc; next?: Doc } {
  const at = DOCS.findIndex((doc) => doc.slug === slug)
  if (at === -1) return {}
  return { prev: DOCS[at - 1], next: DOCS[at + 1] }
}

export function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
}

/**
 * The h2/h3 outline of a doc. Ids are de-duplicated so the rail never renders two
 * identical keys.
 *
 * ponytail: the renderer derives heading ids with plain `slugify`, so a doc with two
 * identically-worded headings gets a second anchor pointing at the first. Rare enough
 * to leave; switch to index-based ids on both sides if it ever bites.
 */
export function headingsOf(body: string): Heading[] {
  const seen = new Map<string, number>()
  const headings: Heading[] = []
  let inFence = false

  for (const line of body.split(/\r?\n/)) {
    if (/^\s*```/.test(line)) {
      inFence = !inFence
      continue
    }
    if (inFence) continue
    const match = /^(#{2,3})\s+(.*)$/.exec(line)
    if (!match) continue
    const text = match[2].replace(/`/g, '').trim()
    const base = slugify(text)
    const count = (seen.get(base) ?? 0) + 1
    seen.set(base, count)
    headings.push({ id: count === 1 ? base : `${base}-${count}`, text, depth: match[1].length as 2 | 3 })
  }
  return headings
}
