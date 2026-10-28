import { Link } from 'react-router-dom'
import { ChevronLeft } from 'lucide-react'
import { Segmented, Switch } from '../../components/ui'
import Screen from '../../components/mission/Screen'
import ListCard from '../../components/mission/ListCard'
import { useTheme } from '../../theme/theme-context'
import { useVoiceInput } from '../../voice/voice-context'
import { liveVoiceSupported } from '../../voice/useLiveVoice'

export default function SettingsAppearance() {
  const { theme, setTheme } = useTheme()
  const { enabled: voiceEnabled, supported: voiceSupported, setEnabled: setVoiceEnabled } =
    useVoiceInput()
  const liveVoice = liveVoiceSupported()
  return (
    <Screen
      eyebrow={
        <Link
          to="/settings"
          className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground"
        >
          <ChevronLeft className="size-3.5" aria-hidden />
          Settings
        </Link>
      }
      title="Voice and appearance"
      description="How the console looks, and whether the composer can hear you."
    >
      <ListCard>
        <div className="flex min-h-14 items-center justify-between gap-4 border-b border-flat-border px-4 py-3">
          <div className="min-w-0">
            <p className="text-native-callout text-flat-foreground">Theme</p>
            <p className="text-sm text-flat-muted-fg">Light or dark.</p>
          </div>
          <Segmented
            value={theme}
            onValueChange={(v) => setTheme(v as 'light' | 'dark')}
            options={[
              { value: 'light', label: 'Light' },
              { value: 'dark', label: 'Dark' },
            ]}
          />
        </div>
        <div className="flex min-h-14 items-center justify-between gap-4 px-4 py-3">
          <div className="min-w-0">
            <p className="text-native-callout text-flat-foreground">Voice input</p>
            <p className="text-sm text-flat-muted-fg">
              {voiceSupported
                ? 'Dictate in the composer, or start live voice in Chat and speak naturally.'
                : 'Voice input is not available in this browser.'}
            </p>
          </div>
          <Switch
            checked={voiceEnabled && voiceSupported}
            onCheckedChange={setVoiceEnabled}
            disabled={!voiceSupported}
            label={voiceEnabled && voiceSupported ? 'On' : 'Off'}
          />
        </div>
      </ListCard>
      <p className="mt-2 px-1 text-2xs text-flat-muted-fg">
        {liveVoice
          ? 'Live voice uses your browser’s speech recognition and spoken replies. Audio processing may happen in the cloud, depending on the browser.'
          : 'Live voice needs a browser with speech recognition, such as Chrome or Edge. Dictation may still work where the browser supports it.'}
      </p>
    </Screen>
  )
}
