/** True when VITE_CLERK_PUBLISHABLE_KEY was set at build time. */
export const clerkEnabled = Boolean(
  import.meta.env.VITE_CLERK_PUBLISHABLE_KEY?.trim(),
)

/** Clerk widget colours that follow the app theme (values match src/themes.css). */
export function clerkAppearance(theme: 'light' | 'dark') {
  const base = { borderRadius: '0.75rem', fontFamily: 'inherit' }
  return {
    variables:
      theme === 'dark'
        ? {
            ...base,
            colorPrimary: '#a9c985',
            colorTextOnPrimaryBackground: '#18211b',
            colorBackground: '#191d1b',
            colorText: '#e8eee9',
            colorTextSecondary: '#a8b2aa',
            colorInputBackground: '#101211',
            colorInputText: '#e8eee9',
            colorNeutral: '#e8eee9',
          }
        : { ...base, colorPrimary: '#4e6a37' },
  }
}
