import React, { useState, useEffect } from 'react'
import Auth from './pages/Auth'
import { Route, Routes } from 'react-router'
import Home from './pages/Home'

const App: React.FC = () => {
	const [token, setToken] = useState<string | null>(null)
	return (
		<Routes>
			<Route path="/login" element={<Auth token={token} updateToken={setToken} />} />
			<Route path="/" element={<Home />} />
		</Routes>

	)
}

export default App
