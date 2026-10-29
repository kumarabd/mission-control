export const semanticKeys = {
  all: ['semantic'] as const,
  page: (section: string, query: string) => ['semantic', section, query] as const,
  item: (key: string) => ['semantic', 'item', key] as const,
  world: () => ['semantic', 'world'] as const,
  source: (parent: string, source: string) => ['semantic', 'source', parent, source] as const,
}

export const notificationKeys = {
  all: ['notifications'] as const,
  list: () => ['notifications', 'list'] as const,
  unread: () => ['notifications', 'unread'] as const,
}
