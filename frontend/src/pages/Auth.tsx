import React, { useState, useEffect } from 'react'


type User = {
	id: number
	email: string
}
interface Props {
	token: string
	// Type for the state updater function
	updateToken: React.Dispatch<React.SetStateAction<string>>
}

const Auth: React.FC<Props> = (props) => {
	const { token, updateToken } = props
	const [mode, setMode] = useState<'login' | 'register'>('login')
	const [email, setEmail] = useState('')
	const [password, setPassword] = useState('')
	const [user, setUser] = useState<User | null>(null)
	const [loading, setLoading] = useState(false)
	const [error, setError] = useState<string | null>(null)
	const [message, setMessage] = useState<string | null>(null)

	const resetMessages = () => {
		setError(null)
		setMessage(null)
	}

	const register = async () => {
		resetMessages()
		setLoading(true)
		setUser(null)

		try {
			const res = await fetch(`/api/users/register`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					Accept: 'application/json',
				},
				body: JSON.stringify({ user: { email, password } }),
				// adapt payload to match your ApiUserRegistrationController params
			})

			if (!res.ok) {
				const body = await res.json().catch(() => ({}))
				throw new Error(body.error || `Register failed with ${res.status}`)
			}

			await res.json().catch(() => ({})) // ignore body; adjust as needed
			setMessage('Registration successful. You can now log in.')
			setMode('login')
		} catch (e: any) {
			setError(e.message ?? 'Unknown error')
		} finally {
			setLoading(false)
		}
	}

	const logout = async () => {
		resetMessages()
		setLoading(true)
		setUser(null)
		try {
			const res = await fetch(`/api/users/logout`, {
				method: 'DELETE',
				headers: {
					'Content-Type': 'application/json',
					Accept: 'application/json',
				},
			})

			if (res.status === 204) {
				// no body to parse
			} else {
				const data = await res.json()
			}

			updateToken(null)
			setMessage('Logged out successfully.')
		} catch (e: any) {
			setError(e.message ?? 'Unknown error')
		} finally {
			setLoading(false)
		}
	}

	const login = async () => {
		resetMessages()
		setLoading(true)
		setUser(null)

		try {
			const res = await fetch(`/api/users/login`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					Accept: 'application/json',
				},
				body: JSON.stringify({ email, password }),
			})

			if (!res.ok) {
				const body = await res.json().catch(() => ({}))
				throw new Error(body.error || `Login failed with ${res.status}`)
			}

			const body = await res.json()
			const t: string = body.token

			updateToken(t)
			setMessage('Logged in successfully.')
		} catch (e: any) {
			setError(e.message ?? 'Unknown error')
		} finally {
			setLoading(false)
		}
	}

	const fetchUser = async (t: string) => {
		setLoading(true)
		setError(null)

		try {
			const res = await fetch(`/api/me`, {
				headers: {
					Authorization: `Bearer ${t}`,
					Accept: 'application/json',
				},
			})

			if (!res.ok) {
				const body = await res.json().catch(() => ({}))
				throw new Error(body.error || `Fetch /me failed with ${res.status}`)
			}

			const body: User = await res.json()
			setUser(body)
		} catch (e: any) {
			setError(e.message ?? 'Unknown error')
		} finally {
			setLoading(false)
		}
	}

	useEffect(() => {
		if (token) {
			void fetchUser(token)
		}
	}, [token])

	const handleSubmit = (e: React.FormEvent) => {
		e.preventDefault()
		if (mode === 'login') {
			void login()
		} else {
			void register()
		}
	}

	return (
		<div className="flex flex-col gap-4">
			<div className="flex gap-3">
				{!token && (
					<>
						<button
							type="button"
							onClick={() => {
								resetMessages()
								setMode('login')
							}}
							disabled={mode === 'login'}
						>
							Login
						</button>
						<button
							type="button"
							onClick={() => {
								resetMessages()
								setMode('register')
							}}
							disabled={mode === 'register'}
						>
							Register
						</button>
					</>
				)}

				{token && (
					<button
						type="button"
						onClick={() => {
							resetMessages()
							void logout()
						}}
					>
						Logout
					</button>
				)}
			</div>

			{!token && (
				<form className="flex flex-col gap-3" onSubmit={handleSubmit}>
					<label className="flex flex-row gap-3">
						Email
						<input value={email} onChange={(e) => setEmail(e.target.value)} />
					</label>
					<label className="flex flex-row gap-2">
						Password
						<input
							type="password"
							value={password}
							onChange={(e) => setPassword(e.target.value)}
						/>
					</label>
					<button type="submit" disabled={loading}>
						{loading ? 'Working...' : mode === 'login' ? 'Login' : 'Register'}
					</button>
				</form>
			)}

			{token && (
				<div>
					<strong>Token:</strong> <code>{token}</code>
				</div>
			)}

			{user && (
				<div>
					<h2>Current user</h2>
					<pre>{JSON.stringify(user, null, 2)}</pre>
				</div>
			)}

			{message && (
				<div>
					<strong>{message}</strong>
				</div>
			)}

			{error && (
				<div>
					<strong>Error:</strong> {error}
				</div>
			)}
		</div>
	)
}

export default Auth
