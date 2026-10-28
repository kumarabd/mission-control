import {
  AlertCircle,
  Bell,
  CalendarDays,
  CheckCircle2,
  HeartPulse,
  Radio,
  Target,
  type LucideIcon,
} from 'lucide-react'

export type MissionTone = 'focus' | 'scheduled' | 'attention' | 'reminder' | 'completed' | 'telemetry' | 'health'

type ToneStyle = {
  label: string
  icon: LucideIcon
  text: string
  bg: string
  border: string
  dot: string
}

/** Native MissionTone: colour is always paired with a symbol and a label. */
export const TONE: Record<MissionTone, ToneStyle> = {
  focus: {
    label: 'Focus',
    icon: Target,
    text: 'text-flat-primary',
    bg: 'bg-flat-tint',
    border: 'border-flat-primary/30',
    dot: 'bg-flat-primary',
  },
  scheduled: {
    label: 'Scheduled',
    icon: CalendarDays,
    text: 'text-flat-scheduled',
    bg: 'bg-flat-scheduled-muted',
    border: 'border-flat-scheduled/25',
    dot: 'bg-flat-scheduled',
  },
  attention: {
    label: 'Needs action',
    icon: AlertCircle,
    text: 'text-flat-attention',
    bg: 'bg-flat-warning-muted',
    border: 'border-flat-attention/30',
    dot: 'bg-flat-attention',
  },
  reminder: {
    label: 'Reminder',
    icon: Bell,
    text: 'text-flat-reminder',
    bg: 'bg-flat-reminder-muted',
    border: 'border-flat-reminder/25',
    dot: 'bg-flat-reminder',
  },
  completed: {
    label: 'Completed',
    icon: CheckCircle2,
    text: 'text-flat-muted-fg',
    bg: 'bg-flat-muted',
    border: 'border-flat-border',
    dot: 'bg-flat-muted-fg',
  },
  telemetry: {
    label: 'System',
    icon: Radio,
    text: 'text-flat-telemetry',
    bg: 'bg-flat-telemetry-muted',
    border: 'border-flat-telemetry/25',
    dot: 'bg-flat-telemetry',
  },
  health: {
    label: 'Health',
    icon: HeartPulse,
    text: 'text-flat-health',
    bg: 'bg-flat-health-muted',
    border: 'border-flat-health/25',
    dot: 'bg-flat-health',
  },
}
