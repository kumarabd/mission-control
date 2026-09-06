export type SourceScope = Readonly<{
  sourceId: string;
  accessScope: string;
}>;

export const queryKeys = {
  portfolio: (scope: SourceScope) => ["portfolio", scope.sourceId, scope.accessScope] as const,
  project: (scope: SourceScope, projectId: string) =>
    ["project", scope.sourceId, scope.accessScope, projectId] as const,
};
