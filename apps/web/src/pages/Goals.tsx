import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { SquarePen } from 'lucide-react'
import AddEventSheet from '../components/today/AddEventSheet'
import AddTaskSheet from '../components/today/AddTaskSheet'
import TaskDetailSheet from '../components/today/TaskDetailSheet'
import EventsList from '../components/goals/EventsList'
import GoalsList from '../components/goals/GoalsList'
import TasksList from '../components/goals/TasksList'
import { IconButton, Segmented } from '../components/ui'
import Screen from '../components/mission/Screen'
import type { Item } from '../lib/life'
import { useChatDraft } from '../lib/chatDraft'

type View = 'goals' | 'tasks' | 'events'

const VIEWS: { value: View; label: string }[] = [
  { value: 'goals', label: 'Goals' },
  { value: 'tasks', label: 'Tasks' },
  { value: 'events', label: 'Events' },
]

const TITLE: Record<View, string> = {
  goals: 'Goals',
  tasks: 'Tasks',
  events: 'Events',
}

const DESCRIPTION: Record<View, string> = {
  goals: 'What you’re working toward.',
  tasks: 'Things to do. A repeating task is a routine; a time is a deadline or a cue.',
  events: 'Things that happen at a set time, whether or not anyone acts.',
}

const NEW_LABEL: Record<View, string> = {
  goals: 'New goal',
  tasks: 'New task',
  events: 'New event',
}

export default function Goals() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const requestDraft = useChatDraft((state) => state.request)
  const [addTaskOpen, setAddTaskOpen] = useState(false)
  const [addEventOpen, setAddEventOpen] = useState(false)
  const [detailItem, setDetailItem] = useState<Item | null>(null)

  const raw = searchParams.get('view')
  const view: View = raw === 'tasks' || raw === 'events' ? raw : 'goals'

  const setView = (next: View) => {
    const params = new URLSearchParams(searchParams)
    if (next === 'goals') params.delete('view')
    else params.set('view', next)
    setSearchParams(params, { replace: true })
  }

  const startNew = () => {
    if (view === 'goals') {
      requestDraft('I want to ')
      navigate('/chat')
    } else if (view === 'tasks') {
      setAddTaskOpen(true)
    } else {
      setAddEventOpen(true)
    }
  }

  return (
    <Screen
      title={TITLE[view]}
      description={DESCRIPTION[view]}
      actions={
        <IconButton label={NEW_LABEL[view]} size="lg" onClick={startNew}>
          <SquarePen aria-hidden />
        </IconButton>
      }
    >
      <Segmented
        className="mb-5"
        fullWidth
        value={view}
        onValueChange={setView}
        options={VIEWS}
      />

      {view === 'goals' && (
        <GoalsList
          onNew={() => {
            requestDraft('I want to ')
            navigate('/chat')
          }}
        />
      )}
      {view === 'tasks' && <TasksList onOpen={setDetailItem} onNew={() => setAddTaskOpen(true)} />}
      {view === 'events' && <EventsList onOpen={setDetailItem} onNew={() => setAddEventOpen(true)} />}

      {addTaskOpen && (
        <AddTaskSheet
          onOpenChange={(open) => {
            if (!open) setAddTaskOpen(false)
          }}
        />
      )}
      {addEventOpen && (
        <AddEventSheet
          onOpenChange={(open) => {
            if (!open) setAddEventOpen(false)
          }}
        />
      )}
      {detailItem && (
        <TaskDetailSheet
          key={detailItem.id}
          item={detailItem}
          onOpenChange={(open) => {
            if (!open) setDetailItem(null)
          }}
          onOpenGoal={(goalId) => {
            setDetailItem(null)
            navigate(`/goals/${goalId}`)
          }}
        />
      )}
    </Screen>
  )
}
