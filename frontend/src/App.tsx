// frontend/src/App.tsx
import React, { useState, useEffect } from "react";

type User = {
	id: number;
	email: string;
};

const API_BASE = "/api"; // proxy to Phoenix

const App: React.FC = () => {
	const [mode, setMode] = useState<"login" | "register">("login");
	const [email, setEmail] = useState("");
	const [password, setPassword] = useState("");
	const [token, setToken] = useState<string | null>(null);
	const [me, setMe] = useState<User | null>(null);
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState<string | null>(null);
	const [message, setMessage] = useState<string | null>(null);

	const resetMessages = () => {
		setError(null);
		setMessage(null);
	};

	const register = async () => {
		resetMessages();
		setLoading(true);
		setMe(null);

		try {
			const res = await fetch(`${API_BASE}/users/register`, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					Accept: "application/json",
				},
				body: JSON.stringify({ user: { email, password } }),
				// adapt payload to match your ApiUserRegistrationController params
			});

			if (!res.ok) {
				const body = await res.json().catch(() => ({}));
				throw new Error(body.error || `Register failed with ${res.status}`);
			}

			await res.json().catch(() => ({})); // ignore body; adjust as needed
			setMessage("Registration successful. You can now log in.");
			setMode("login");
		} catch (e: any) {
			setError(e.message ?? "Unknown error");
		} finally {
			setLoading(false);
		}
	};

	const logout = async () => {
		resetMessages();
		setLoading(true);
		setMe(null);
		try {
			const res = await fetch(`${API_BASE}/users/logout`, {
				method: "DELETE",
				headers: {
					"Content-Type": "application/json",
					Accept: "application/json",
				},
			});

			if (res.status === 204) {
				// no body to parse
			} else {
				const data = await res.json();
			}

			setToken(null);
			setMessage("Logged out successfully.");
		} catch (e: any) {
			setError(e.message ?? "Unknown error");
		} finally {
			setLoading(false);
		}
	}

	const login = async () => {
		resetMessages();
		setLoading(true);
		setMe(null);

		try {
			const res = await fetch(`${API_BASE}/users/login`, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					Accept: "application/json",
				},
				body: JSON.stringify({ email, password }),
			});

			if (!res.ok) {
				const body = await res.json().catch(() => ({}));
				throw new Error(body.error || `Login failed with ${res.status}`);
			}

			const body = await res.json();
			const t: string = body.token;

			setToken(t);
			setMessage("Logged in successfully.");
		} catch (e: any) {
			setError(e.message ?? "Unknown error");
		} finally {
			setLoading(false);
		}
	};

	const fetchMe = async (t: string) => {
		setLoading(true);
		setError(null);

		try {
			const res = await fetch(`${API_BASE}/me`, {
				headers: {
					Authorization: `Bearer ${t}`,
					Accept: "application/json",
				},
			});

			if (!res.ok) {
				const body = await res.json().catch(() => ({}));
				throw new Error(body.error || `Fetch /me failed with ${res.status}`);
			}

			const body: User = await res.json();
			setMe(body);
		} catch (e: any) {
			setError(e.message ?? "Unknown error");
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		if (token) {
			void fetchMe(token);
		}
	}, [token]);

	const handleSubmit = (e: React.FormEvent) => {
		e.preventDefault();
		if (mode === "login") {
			void login();
		} else {
			void register();
		}
	};

	return (
		<div style={{ maxWidth: 480, margin: "2rem auto", fontFamily: "sans-serif" }}>

			<div style={{ marginBottom: "1rem" }}>
				<button
					type="button"
					onClick={() => {
						resetMessages();
						setMode("login");
					}}
					disabled={mode === "login"}
					style={{ marginRight: 8 }}
				>
					Login
				</button>
				<button
					type="button"
					onClick={() => {
						resetMessages();
						setMode("register");
					}}
					disabled={mode === "register"}
				>
					Register
				</button>

				<button
					type="button"
					onClick={() => {
						resetMessages();
						void logout();
					}}
				>
					Logout
				</button>
			</div>

			<form onSubmit={handleSubmit}>
				<label>
					Email
					<input
						value={email}
						onChange={(e) => setEmail(e.target.value)}
						style={{ display: "block", width: "100%", marginTop: 4 }}
					/>
				</label>
				<label style={{ marginTop: 8, display: "block" }}>
					Password
					<input
						type="password"
						value={password}
						onChange={(e) => setPassword(e.target.value)}
						style={{ display: "block", width: "100%", marginTop: 4 }}
					/>
				</label>
				<button type="submit" disabled={loading} style={{ marginTop: 12 }}>
					{loading
						? "Working..."
						: mode === "login"
							? "Login"
							: "Register"}
				</button>

			</form>

			{token && (
				<div style={{ marginTop: "1rem" }}>
					<strong>Token:</strong> <code>{token}</code>
				</div>
			)}

			{me && (
				<div style={{ marginTop: "1rem" }}>
					<h2>Current user</h2>
					<pre>{JSON.stringify(me, null, 2)}</pre>
				</div>
			)}

			{message && (
				<div style={{ marginTop: "0.5rem", color: "green" }}>
					<strong>{message}</strong>
				</div>
			)}

			{error && (
				<div style={{ marginTop: "0.5rem", color: "red" }}>
					<strong>Error:</strong> {error}
				</div>
			)}
		</div>
	);
};

export default App;
