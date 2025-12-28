import React from 'react'
import Auth from './pages/Auth'
import { Route, Routes } from 'react-router'
import Home from './pages/Home'
import { AuthProvider } from './contexts/AuthContext'
import { LocationProvider } from './contexts/LocationContext'
import { ProtectedRoute } from './components/ProtectedRoute'
import Nav from './components/Nav'
import { DevLocationPanel } from './components/DevLocationPanel'

const App: React.FC = () => {
  return (
    <AuthProvider>
      <LocationProvider>
        <div className="h-screen w-screen flex flex-col">
          <Nav />
          <div className="flex-1">
            <Routes>
              <Route path="/login" element={<Auth />} />
              <Route path="/" element={
                <ProtectedRoute>
                  <Home />
                </ProtectedRoute>
              } />
            </Routes>
          </div>
          <DevLocationPanel />
        </div>
      </LocationProvider>
    </AuthProvider>
  )
}

export default App
