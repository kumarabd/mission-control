---
title: Learn
group: Concepts
order: 3
summary: Teach a skill, where progress means the learner did the exercise.
status: extends + new
related: concepts/loops/companion, concepts/loops/watch
---

Progress here is demonstrated performance. The model's sense that the learner seems to get it does not count. Like the companion, it is a profile of the surface, because the dialogue is the work.

```loop
learn
```

**State.** A skill progress model: level, curriculum position, what is shaky, and the spaced-review queue. Durable across sessions, which is the real build.
**Composition.** Nothing here needs its own engine. Teaching and grading an exercise is the surface itself. Curriculum and exercise preparation is a `produce` task the surface delegates. Spaced review is a `watch`.
**Rails.** Progress means demonstrated performance. The learner did the exercise.
**Exits.** The session goal is met and the next session is scheduled, or the user pauses the course.
**Handoffs.** To `produce` for preparation, and to `research` for depth beyond the session.

> [!QUESTION]
> **When to promote it.** If building a curriculum turns out to need its own iteration driver, `learn` becomes an engine. What would that look like in practice?

> [!QUESTION]
> **Format.** How much is quiz-and-feedback, with the agent running the session, versus pointing at resources and checking in?

> [!QUESTION]
> **Cadence.** Does the first session end with a real scheduled cadence, or leave it to the user?
