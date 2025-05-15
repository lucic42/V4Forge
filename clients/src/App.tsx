"use client"

import { Routes, Route } from "react-router-dom"
import Dashboard from "./pages/Dashboard"
import DutchAuction from "./pages/DutchAuction"
import ExponentialLaunch from "./pages/ExponentialLaunch"
import CreateLaunch from "./pages/CreateLaunch"
import TokenDetails from "./pages/TokenDetails"
import { AnimatePresence } from "framer-motion"
import { ParticlesBackground } from "./components/ParticlesBackground"
import { useLocation } from "react-router-dom"
import { useEffect, useState } from "react"
import RootLayout from "./Layout/Layout"
import LandingPage from "./pages/LandingPage"
import AirdropPage from "./pages/Aidrop"

function AppRoutes() {
  const location = useLocation()
  const [showParticles, setShowParticles] = useState(true)

  // Disable particles on certain routes for better performance
  useEffect(() => {
    setShowParticles(location.pathname === "/" || location.pathname === "/create")
  }, [location])

  return (
    <>
      {showParticles && <ParticlesBackground />}
      <AnimatePresence mode="wait">
        <Routes location={location} key={location.pathname}>
          <Route path="/" element={<LandingPage />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/dutch-auction/:id" element={<DutchAuction />} />
          <Route path="/exponential-launch/:id" element={<ExponentialLaunch />} />
          <Route path="/airdrop" element={<AirdropPage />} />
          <Route path="/create" element={<CreateLaunch />} />
          <Route path="/token/:id" element={<TokenDetails />} />
        </Routes>
      </AnimatePresence>
    </>
  )
}

function App() {
  return (
    <RootLayout>
      <AppRoutes />
    </RootLayout>
  )
}

export default App
