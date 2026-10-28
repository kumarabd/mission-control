import { describe, expect, it } from 'vitest'
import { stripToolCallText } from './toolCallText'

describe('stripToolCallText', () => {
  it('leaves plain replies alone', () => {
    expect(stripToolCallText('Bring the bins out.')).toBe('Bring the bins out.')
  })

  it('removes a closed call whole', () => {
    expect(
      stripToolCallText(`Done.
<tool_call>
<function=shell_exec>
<parameter=command>ls</parameter>
</function>
</tool_call>`),
    ).toBe('Done.')
  })

  it('keeps the text before a call whose opener was cut off', () => {
    expect(
      stripToolCallText(`Which date in March is your 10k race day?</parameter>
</function>
</tool_call>
<tool_call>
<function=shell_exec>
<parameter=command>ls</parameter>`),
    ).toBe('Which date in March is your 10k race day?')
  })

  it('keeps the answer after a closed call', () => {
    expect(
      stripToolCallText(`<tool_call>
<function=shell_exec>
<parameter=command>ls</parameter>
</function>
</tool_call>
Here it is.`),
    ).toBe('Here it is.')
  })
})
