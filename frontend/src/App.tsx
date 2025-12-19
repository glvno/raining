import React, { useState, useEffect } from "react";
import AuthForm from "./components/AuthForm";



const App: React.FC = () => {
	const [token, setToken] = useState<string | null>(null);
	return (
		<AuthForm token={token} updateToken={setToken} />
	);
};

export default App;
