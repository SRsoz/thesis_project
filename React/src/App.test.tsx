import { afterEach, describe, expect, test, vi } from 'vitest'
import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import App from './App'

afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})

describe('App upload form', () => {
  test('uploads png files and resets the form after success', async () => {
    const fetchMock = mockFetchResponse({
      ok: true,
      status: 201,
      body: { message: 'Upload successful' },
    })

    const user = userEvent.setup()
    render(<App />)
    const file = new File(['file contents'], 'pixel.png', {
      type: 'image/png',
    })

    await user.upload(screen.getByLabelText('Choose file'), file)
    expect(screen.getByText('pixel.png')).toBeTruthy()

    await user.click(screen.getByRole('button', { name: 'Upload file' }))

    expect(await screen.findByText('Upload successful')).toBeTruthy()
    expect(screen.getByText('no file chosen')).toBeTruthy()
    expect(fetchMock).toHaveBeenCalledTimes(1)

    const [url, options] = fetchMock.mock.calls[0]
    expect(url).toBe('http://localhost:3000/api/uploads')
    expect(options).toMatchObject({ method: 'POST' })
    expect(options?.body).toBeInstanceOf(FormData)
    expect((options?.body as FormData).get('file')).toBeInstanceOf(File)
  })

  test('shows an error and does not call the backend when submitting without a file', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch')
    const user = userEvent.setup()

    render(<App />)
    await user.click(screen.getByRole('button', { name: 'Upload file' }))

    expect(screen.getByText('upload failed')).toBeTruthy()
    expect(fetchMock).not.toHaveBeenCalled()
  })

  test('shows the backend error message when upload fails', async () => {
    mockFetchResponse({
      ok: false,
      status: 415,
      body: { message: 'Only png files allowed' },
    })

    const user = userEvent.setup()
    const file = new File(['file contents'], 'pixel.png', { type: 'image/png' })

    render(<App />)
    await user.upload(screen.getByLabelText('Choose file'), file)
    await user.click(screen.getByRole('button', { name: 'Upload file' }))

    expect(await screen.findByText('Only png files allowed')).toBeTruthy()
    await waitFor(() => {
      expect(screen.queryByText('Upload successful')).toBeNull()
    })
  })
})

function mockFetchResponse({
  ok,
  status,
  body,
}: {
  ok: boolean
  status: number
  body: unknown
}) {
  return vi.spyOn(globalThis, 'fetch').mockResolvedValue({
    ok,
    status,
    json: async () => body,
  } as Response)
}
