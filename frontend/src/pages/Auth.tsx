import { useState, useEffect } from 'react'
import type { FormEvent } from 'react'
import { useNavigate } from 'react-router'
import { useAuth } from '../contexts/AuthContext'

const Auth: React.FC = () => {
	const navigate = useNavigate()
	const { login, register, error, clearError, isAuthenticated } = useAuth()

	const [mode, setMode] = useState<'login' | 'register'>('login')
	const [email, setEmail] = useState('')
	const [password, setPassword] = useState('')
	const [isSubmitting, setIsSubmitting] = useState(false)

	// Redirect to home if already authenticated
	useEffect(() => {
		if (isAuthenticated) {
			navigate('/', { replace: true })
		}
	}, [isAuthenticated, navigate])

	const handleSubmit = async (e: FormEvent) => {
		e.preventDefault()
		setIsSubmitting(true)
		clearError()

		try {
			if (mode === 'login') {
				await login(email, password)
				// Will redirect via useEffect
			} else {
				await register(email, password)
				// Will redirect via useEffect
			}
		} catch {
			// Error is already set in AuthContext
		} finally {
			setIsSubmitting(false)
		}
	}

	const switchMode = (newMode: 'login' | 'register') => {
		setMode(newMode)
		clearError()
	}

	return (
		<div className="min-h-full bg-gradient-to-br from-blue-50 to-gray-100 flex items-center justify-center px-4 py-12">
			<div className="bg-white rounded-lg shadow-lg p-8 w-full max-w-md">
				<div className="text-center mb-8">
					<h1 className="text-4xl font-bold text-gray-900 mb-2">🌧️ Raining</h1>
					<p className="text-gray-600">
						{mode === 'login' ? 'Welcome back!' : 'Create your account'}
					</p>
				</div>

				<div className="flex gap-2 mb-6">
					<button
						type="button"
						onClick={() => switchMode('login')}
						className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
							mode === 'login'
								? 'bg-blue-500 text-white'
								: 'bg-gray-200 text-gray-700 hover:bg-gray-300'
						}`}
					>
						Login
					</button>
					<button
						type="button"
						onClick={() => switchMode('register')}
						className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
							mode === 'register'
								? 'bg-blue-500 text-white'
								: 'bg-gray-200 text-gray-700 hover:bg-gray-300'
						}`}
					>
						Register
					</button>
				</div>

				<form onSubmit={handleSubmit} className="space-y-4">
					<div>
						<label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
							Email
						</label>
						<input
							id="email"
							type="email"
							value={email}
							onChange={(e) => setEmail(e.target.value)}
							required
							className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							placeholder="you@example.com"
							disabled={isSubmitting}
						/>
					</div>

					<div>
						<label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
							Password
						</label>
						<input
							id="password"
							type="password"
							value={password}
							onChange={(e) => setPassword(e.target.value)}
							required
							className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							placeholder="••••••••"
							disabled={isSubmitting}
						/>
					</div>

					<button
						type="submit"
						disabled={isSubmitting}
						className={`w-full py-3 rounded-lg font-medium transition-colors ${
							isSubmitting
								? 'bg-gray-300 text-gray-500 cursor-not-allowed'
								: 'bg-blue-500 text-white hover:bg-blue-600'
						}`}
					>
						{isSubmitting ? 'Please wait...' : mode === 'login' ? 'Login' : 'Create Account'}
					</button>
				</form>


				{error && (
					<div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
						<p className="text-sm text-red-800">{error}</p>
					</div>
				)}
			</div>
		</div>
	)
}

export default Auth
