import { useInfiniteQuery, useQuery } from '@tanstack/react-query'
import {
  getMemoryFacts,
  getSemanticMemory,
  getSemanticSource,
  getSemanticWorld,
  type SemanticSection,
} from './api'
import { semanticKeys } from './life/queryKeys'

const PAGE_SIZE = 20

/** The curated, read-only semantic projection: Reflections and About you. */
export function useSemanticMemory(section: SemanticSection, query: string, enabled = true) {
  return useInfiniteQuery({
    enabled,
    queryKey: semanticKeys.page(section, query),
    queryFn: ({ pageParam }) =>
      getSemanticMemory(section, { q: query, limit: PAGE_SIZE, offset: pageParam }),
    initialPageParam: 0,
    getNextPageParam: (last) =>
      last.has_more ? last.offset + last.items.length : undefined,
    placeholderData: (previous, previousQuery) =>
      previousQuery?.queryKey[1] === section ? previous : undefined,
    staleTime: 60_000,
    retry: 1,
  })
}

/** The world model: entities with their profiles and the typed relations among them. */
export function useSemanticWorld(enabled = true) {
  return useQuery({
    queryKey: semanticKeys.world(),
    queryFn: () => getSemanticWorld(),
    enabled,
    staleTime: 60_000,
    retry: 1,
  })
}

export function useSemanticSource(parent: string, source: string, enabled = true) {
  return useQuery({
    queryKey: semanticKeys.source(parent, source),
    queryFn: () => getSemanticSource(parent, source),
    enabled: Boolean(parent && source) && enabled,
    retry: false,
  })
}

/** Related memory for one entity, alongside a semantic item. */
export function useEntityMemoryFacts(entityId: string, enabled = true) {
  return useQuery({
    queryKey: [...semanticKeys.all, 'entity', entityId] as const,
    queryFn: () => getMemoryFacts({ entityId, limit: 20 }),
    enabled: Boolean(entityId) && enabled,
    retry: false,
  })
}

/** Native label vocabulary; the engine's `kind` is an implementation detail. */
export function semanticKindLabel(kind: string): string {
  switch (kind) {
    case 'observation':
      return 'Observation'
    case 'personal_model':
      return 'Personal understanding'
    case 'mental_model':
      return 'Reflection'
    default:
      return 'Insight'
  }
}

export function semanticSectionTitle(section: SemanticSection): string {
  return section === 'reflections' ? 'Reflections' : 'About you'
}
