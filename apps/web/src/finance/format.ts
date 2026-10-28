/** Keep aggregate strings exact, including totals larger than JavaScript's safe integer range. */
export function formatMoney(minor: string | number, currency: string, locale?: string): string {
  const value = BigInt(minor)
  const format = new Intl.NumberFormat(locale, { style: 'currency', currency })
  const digits = format.resolvedOptions().maximumFractionDigits ?? 2
  const scale = 10n ** BigInt(digits)
  const absolute = value < 0n ? -value : value
  const whole = absolute / scale
  const signedWhole = value < 0n ? (whole === 0n ? -0 : -whole) : whole
  const fraction = (absolute % scale).toString().padStart(digits, '0')
  return format.formatToParts(signedWhole).map((part) => part.type === 'fraction' ? fraction : part.value).join('')
}

export function formatDate(date: string): string {
  // A finance date is a calendar date, not a UTC instant that shifts in the browser's timezone.
  const [year, month, day] = date.split('-').map(Number)
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(new Date(year, month - 1, day, 12))
}

export function monthWindow(now = new Date()) {
  const date = (day: number) => `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
  return { from: date(1), to: date(now.getDate()) }
}
