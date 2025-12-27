import { NavLink } from "react-router"
import { useAuth } from "../contexts/AuthContext"

const Nav: React.FC = () => {
	const { user, isAuthenticated, logout } = useAuth()

	const handleLogout = async () => {
		await logout()
	}

	return (
		<nav className="bg-white shadow-sm px-6 py-4 flex justify-between items-center">
			<NavLink to="/" className="flex items-center gap-2 text-xl font-bold text-gray-900 hover:text-blue-600 transition-colors">
				<span>🌧️</span>
				<span>Raining</span>
			</NavLink>

			<div className="flex gap-4 items-center">
				{isAuthenticated ? (
					<>
						<span className="text-gray-600">{user?.email}</span>
						<button
							onClick={handleLogout}
							className="px-4 py-2 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300 transition-colors"
						>
							Logout
						</button>
					</>
				) : (
					<NavLink
						to="/login"
						className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
					>
						Login
					</NavLink>
				)}
			</div>
		</nav>
	)
}
export default Nav 
