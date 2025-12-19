import React, { useState, useEffect } from 'react'
import Auth from './pages/Auth'

const App: React.FC = () => {
	const [token, setToken] = useState<string | null>(null)
	return <AuthForm token={token} updateToken={setToken} />
}

export default App
