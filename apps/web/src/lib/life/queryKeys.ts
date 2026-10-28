export const lifeKeys = {
  all: ['life'] as const,
  settings: () => ['life', 'settings'] as const,
  day: () => ['life', 'day'] as const,
  tasks: () => ['life', 'tasks'] as const,
  events: () => ['life', 'events'] as const,
  taskHistory: (id: string, days = 30) => ['life', 'task-history', id, days] as const,
  item: (id: string) => ['life', 'item', id] as const,
  goals: () => ['life', 'goals'] as const,
  goal: (id: string) => ['life', 'goal', id] as const,
  goalItems: (id: string) => ['life', 'goal-items', id] as const,
  trackers: () => ['life', 'tracker'] as const,
  tracker: (goalId: string, catalogId: string) => ['life', 'tracker', goalId, catalogId] as const,
  series: (provider: string, series: string, from: string, to: string, granularity: string) =>
    ['life', 'series', provider, series, from, to, granularity] as const,
}

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
