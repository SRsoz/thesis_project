import { useState } from 'react'
import './App.css'

function App() {
  const [file, setFile] = useState<File | null>(null)
  const [message, setMessage] = useState('')
  const [isSuccess, setIsSuccess] = useState(false)

  async function handleUpload(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = event.currentTarget

    if (!file) {
      setMessage('upload failed')
      setIsSuccess(false)
      return
    }

    const formData = new FormData()
    formData.append('file', file)

    try {
      const response = await fetch('http://localhost:3000/api/uploads', {
        method: 'POST',
        body: formData,
      })
      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.message || 'upload failed')
      }

      setMessage(data.message || 'upload successful')
      setIsSuccess(true)
      setFile(null)
      form.reset()
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'upload failed')
      setIsSuccess(false)
    }
  }

  return (
    <main className="page">
      <form className="upload-form" onSubmit={handleUpload}>
        <label className="file-button" htmlFor="file-input">
          Choose file
        </label>

        <input
          id="file-input"
          className="file-input"
          type="file"
          onChange={(event) => setFile(event.target.files?.[0] ?? null)}
        />

        <p className="file-name">{file ? file.name : 'no file chosen'}</p>

        <button className="upload-button" type="submit">
          Upload file
        </button>

        {message && (
          <p className={`message ${isSuccess ? 'success' : 'error'}`}>
            {message}
          </p>
        )}
      </form>
    </main>
  )
}

export default App
