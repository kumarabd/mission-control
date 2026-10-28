import { Tabs } from './Tabs'

export type TabItem<T extends string> = {
  id: T
  label: string
  description?: string
}

/** @deprecated compat shim over <Tabs>. New code should use Tabs / RoutedTabs. */
export default function TabBar<T extends string>({
  items,
  active,
  onChange,
  className,
}: {
  items: TabItem<T>[]
  active: T
  onChange: (id: T) => void
  className?: string
}) {
  return (
    <Tabs
      className={className}
      value={active}
      onValueChange={(v) => onChange(v as T)}
      items={items.map((i) => ({ value: i.id, label: i.label }))}
    />
  )
}
