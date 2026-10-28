import { create } from 'zustand'
import type { TripFilter } from '../utils/trips'

/** Pseudo sensor id for the speed chart, which comes from the drive's route samples rather than a stored PID. */
export const SPEED_SERIES = 'speed'

export type DaysWindow = 7 | 30 | 90

interface DriveState {
  /** The sensor charted in the detail view. */
  selectedPid: string
  selectPid: (pid: string) => void
  resetPid: () => void
  days: DaysWindow
  setDays: (d: DaysWindow) => void
  /** Which trips the list shows: those you drove, those you only planned, or both. */
  filter: TripFilter
  setFilter: (f: TripFilter) => void
}

export const useDriveStore = create<DriveState>((set) => ({
  selectedPid: SPEED_SERIES,
  selectPid: (selectedPid) => set({ selectedPid }),
  resetPid: () => set({ selectedPid: SPEED_SERIES }),
  days: 30,
  setDays: (days) => set({ days }),
  filter: 'all',
  setFilter: (filter) => set({ filter }),
}))
