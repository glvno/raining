import { NavLink } from "react-router"

const Nav: React.FC = () => {
	return (
		<nav className="flex justify-around gap-3">
			<NavLink to="/" end>
				Home
			</NavLink>
			<NavLink to="/login" end>Login</NavLink>
		</nav>
	)
}
export default Nav 
