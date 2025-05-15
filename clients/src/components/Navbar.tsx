"use client"
import { Link, useLocation } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { ModeToggle } from "./mode-toggle"
import { Code2, LayoutDashboard, Zap } from "lucide-react"
import { motion } from "framer-motion"
import { useEffect, useState } from "react"
import ConnectWallet from "./ConnectButton"

const Navbar = () => {
  const [scrolled, setScrolled] = useState(false)
  const location = useLocation()

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 10)
    }
    window.addEventListener("scroll", handleScroll)
    return () => window.removeEventListener("scroll", handleScroll)
  }, [])

  return (
    <motion.nav
      className={`sticky top-0 z-50 transition-all duration-300 ${scrolled ? "backdrop-blur-md bg-background/80 shadow-md" : "bg-transparent"
        }`}
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      transition={{ type: "spring", stiffness: 100, damping: 20 }}
    >
      <div className="container mx-auto flex items-center justify-between h-16 px-4">
        <Link to="/" className="flex items-center space-x-2">
          <motion.div className="relative" whileHover={{ scale: 1.1 }} transition={{ duration: 0.3 }}>
            <Code2 className="h-6 w-6 text-teal-500" />
            <motion.div
              className="absolute -inset-1 rounded-full bg-teal-500/20 -z-10"
              animate={{
                scale: [1, 1.2, 1],
                opacity: [0.5, 0.8, 0.5],
              }}
              transition={{
                duration: 2,
                repeat: Number.POSITIVE_INFINITY,
                repeatType: "loop",
              }}
            />
          </motion.div>
          <motion.span
            className="font-bold text-xl bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 }}
          >
            V4Forge
          </motion.span>
        </Link>

        <div className="flex items-center space-x-2">

          <Link to="/dashboard">
            <Button
              variant="ghost"
              size="sm"
              className={location.pathname === "/dashboard" ? "text-teal-500" : "text-muted-foreground"}
            >
              <LayoutDashboard className="h-4 w-4 mr-1" />
              Dashboard
            </Button>
          </Link>

          <Link to="/airdrop">
            <Button
              variant="ghost"
              size="sm"
              className={location.pathname === "/airdrop" ? "text-teal-500" : "text-muted-foreground"}
            >
              <Zap className="h-4 w-4 mr-1" />
              Airdrop
            </Button>
          </Link>

          <Link to="/create">
            <Button
              variant="outline"
              size="sm"
              className="border-teal-500/50 hover:border-teal-500 hover:bg-teal-500/10 transition-all duration-300"
            >
              Create Launch
            </Button>
          </Link>

          <ModeToggle />

          <ConnectWallet />
        </div>
      </div>
    </motion.nav>
  )
}

export default Navbar
