"use client"
import { Link, useLocation } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { ModeToggle } from "./mode-toggle"
import { Code2, LayoutDashboard, Zap, Menu, X, Home } from "lucide-react"
import { motion, AnimatePresence } from "framer-motion"
import { useEffect, useState } from "react"
import ConnectWallet from "./ConnectButton"

const Navbar = () => {
  const [scrolled, setScrolled] = useState(false)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const location = useLocation()

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 10)
    }
    window.addEventListener("scroll", handleScroll)
    return () => window.removeEventListener("scroll", handleScroll)
  }, [])

  // Close mobile menu when route changes
  useEffect(() => {
    setMobileMenuOpen(false)
  }, [location])

  // Prevent scrolling when mobile menu is open
  useEffect(() => {
    if (mobileMenuOpen) {
      document.body.style.overflow = "hidden"
    } else {
      document.body.style.overflow = "unset"
    }
    return () => {
      document.body.style.overflow = "unset"
    }
  }, [mobileMenuOpen])

  const navItems = [
    { path: "/", label: "Home", icon: Home },
    { path: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
    { path: "/airdrop", label: "Airdrop", icon: Zap },
  ]

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

        {/* Desktop Navigation */}
        <div className="hidden md:flex items-center space-x-2">
          {navItems.map((item) => (
            <Link key={item.path} to={item.path}>
              <Button
                variant="ghost"
                size="sm"
                className={location.pathname === item.path ? "text-teal-500" : "text-muted-foreground"}
              >
                <item.icon className="h-4 w-4 mr-1" />
                {item.label}
              </Button>
            </Link>
          ))}

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

        {/* Mobile Navigation Toggle */}
        <div className="flex items-center space-x-2 md:hidden">
          <ModeToggle />

          <Button
            variant="ghost"
            size="icon"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="text-teal-500"
          >
            {mobileMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </Button>
        </div>
      </div>

      {/* Mobile Menu */}
      <AnimatePresence>
        {mobileMenuOpen && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.3 }}
            className="md:hidden bg-background/95 backdrop-blur-md border-b border-teal-500/10"
          >
            <div className="container mx-auto py-4 px-4 space-y-4">
              {navItems.map((item) => (
                <Link key={item.path} to={item.path}>
                  <Button
                    variant="ghost"
                    size="sm"
                    className={`w-full justify-start ${location.pathname === item.path ? "text-teal-500 bg-teal-500/10" : "text-muted-foreground"
                      }`}
                  >
                    <item.icon className="h-4 w-4 mr-2" />
                    {item.label}
                  </Button>
                </Link>
              ))}

              <Link to="/create" className="block">
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full justify-start border-teal-500/50 hover:border-teal-500 hover:bg-teal-500/10"
                >
                  Create Launch
                </Button>
              </Link>

              <div className="pt-2 border-t border-teal-500/10">
                <ConnectWallet />
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.nav>
  )
}

export default Navbar
