"use client"

import { useState, useEffect } from "react"
import { Link } from "react-router-dom"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { ArrowRight, ChevronRight, BarChart3, Layers, Rocket, Shield, Code, Zap, TrendingUp, Clock } from "lucide-react"
import { mockLaunches } from "@/lib/mock-data"
import { formatDistanceToNow } from "date-fns"
import { motion } from "framer-motion"
import { TokenModel } from "@/components/TokenModel"
import TerminalShowcase from "@/components/TerminalShowcase"

const LandingPage = () => {
  const [activeTab, setActiveTab] = useState("all")
  const [launches, setLaunches] = useState(mockLaunches)
  const [selectedToken, setSelectedToken] = useState<string | null>(null)
  const [scrollY, setScrollY] = useState(0)

  useEffect(() => {
    const handleScroll = () => {
      setScrollY(window.scrollY)
    }
    window.addEventListener("scroll", handleScroll)
    return () => window.removeEventListener("scroll", handleScroll)
  }, [])

  const filterLaunches = (tab: string) => {
    if (tab === "all") return mockLaunches
    return mockLaunches.filter((launch) => launch.type === tab)
  }

  useEffect(() => {
    setLaunches(filterLaunches(activeTab))
  }, [activeTab])

  const container = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
      },
    },
  }

  const item = {
    hidden: { y: 20, opacity: 0 },
    show: { y: 0, opacity: 1 },
  }

  const features = [
    {
      icon: Rocket,
      title: "Instant Launch",
      description: "Deploy your token in minutes with our streamlined process. No coding required.",
    },
    {
      icon: Shield,
      title: "Secure Contracts",
      description: "Our smart contracts are built on top of Uniswap v4, ensuring security and reliability.",
    },
    {
      icon: TrendingUp,
      title: "Dutch Auctions",
      description: "Launch with a Dutch auction mechanism where price decreases over time until sold out.",
    },
    {
      icon: Clock,
      title: "Exponential Launches",
      description: "Use an exponential price curve that increases as more tokens are purchased.",
    },
    {
      icon: BarChart3,
      title: "Token Analytics",
      description: "Track your token's performance with detailed analytics and insights.",
    },
    {
      icon: Code,
      title: "Uniswap V4 Hooks",
      description: "Leverage the power of Uniswap V4 hooks for advanced token functionality.",
    },
  ]

  return (
    <div className="space-y-12">
      {/* Hero Section */}
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-teal-500/5 via-blue-500/5 to-transparent -z-10"></div>

        <div className="container mx-auto px-4 py-16">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <motion.div
              className="text-left"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8 }}
            >
              <Badge
                variant="outline"
                className="px-3 py-1 border-teal-500/50 bg-background/50 text-teal-500 backdrop-blur-sm mb-6"
              >
                <Zap className="h-3.5 w-3.5 mr-1" />
                Uniswap V4 Token Launchpad
              </Badge>

              <h1 className="text-4xl md:text-6xl font-bold mb-6 bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
                Launch Tokens <br />
                With Zero Code
              </h1>

              <p className="text-xl text-muted-foreground mb-8 max-w-2xl">
                Create and deploy tokens on Uniswap V4 with advanced mechanisms like Dutch Auctions and Exponential
                Launches - all without writing a single line of code.
              </p>

              <div className="flex flex-col sm:flex-row gap-4">
                <Link to="/create">
                  <Button
                    size="lg"
                    className="bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600 h-12 px-8"
                  >
                    Create Token Launch
                    <ArrowRight className="ml-2 h-4 w-4" />
                  </Button>
                </Link>

                <Link to="/dashboard">
                  <Button
                    size="lg"
                    variant="outline"
                    className="border-teal-500/50 hover:border-teal-500 hover:bg-teal-500/10 h-12 px-8"
                  >
                    Go to Dashboard
                    <ChevronRight className="ml-2 h-4 w-4" />
                  </Button>
                </Link>
              </div>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.8, delay: 0.2 }}
              className="w-full max-w-xl mx-auto lg:mx-0"
            >
              <TerminalShowcase />
            </motion.div>
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="py-12 border-y border-teal-500/10 backdrop-blur-sm bg-background/40">
        <div className="container mx-auto px-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5 }}
              viewport={{ once: true }}
              className="bg-background/40 backdrop-blur-sm border border-teal-500/10 rounded-lg p-6"
            >
              <div className="flex items-center gap-4">
                <div className="rounded-md bg-teal-500/10 border border-teal-500/20 w-12 h-12 flex items-center justify-center text-teal-500">
                  <Layers className="h-6 w-6" />
                </div>
                <div>
                  <p className="text-muted-foreground text-sm">Total Tokens</p>
                  <div className="flex items-baseline gap-2">
                    <h3 className="text-2xl font-bold">1,234</h3>
                    <span className="text-green-500 text-sm">+12.5%</span>
                  </div>
                </div>
              </div>
              <p className="text-xs text-muted-foreground mt-4">Tokens created this month</p>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.1 }}
              viewport={{ once: true }}
              className="bg-background/40 backdrop-blur-sm border border-teal-500/10 rounded-lg p-6"
            >
              <div className="flex items-center gap-4">
                <div className="rounded-md bg-teal-500/10 border border-teal-500/20 w-12 h-12 flex items-center justify-center text-teal-500">
                  <BarChart3 className="h-6 w-6" />
                </div>
                <div>
                  <p className="text-muted-foreground text-sm">Trading Volume</p>
                  <div className="flex items-baseline gap-2">
                    <h3 className="text-2xl font-bold">$4.2M</h3>
                    <span className="text-green-500 text-sm">+8.3%</span>
                  </div>
                </div>
              </div>
              <p className="text-xs text-muted-foreground mt-4">24h trading volume</p>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.2 }}
              viewport={{ once: true }}
              className="bg-background/40 backdrop-blur-sm border border-teal-500/10 rounded-lg p-6"
            >
              <div className="flex items-center gap-4">
                <div className="rounded-md bg-teal-500/10 border border-teal-500/20 w-12 h-12 flex items-center justify-center text-teal-500">
                  <Rocket className="h-6 w-6" />
                </div>
                <div>
                  <p className="text-muted-foreground text-sm">Active Users</p>
                  <div className="flex items-baseline gap-2">
                    <h3 className="text-2xl font-bold">5,678</h3>
                    <span className="text-green-500 text-sm">+15.2%</span>
                  </div>
                </div>
              </div>
              <p className="text-xs text-muted-foreground mt-4">Users this week</p>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-16 relative overflow-hidden">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] rounded-full bg-gradient-radial from-teal-500/5 via-teal-500/2 to-transparent -z-10"></div>

        <div className="container mx-auto px-4">
          <div className="text-center mb-12">
            <Badge
              variant="outline"
              className="px-3 py-1 border-teal-500/50 bg-background/50 text-teal-500 backdrop-blur-sm mb-4"
            >
              <Code className="h-3.5 w-3.5 mr-1" />
              Features
            </Badge>

            <h2 className="text-3xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
              Why Choose V4Forge?
            </h2>

            <p className="text-xl text-muted-foreground max-w-3xl mx-auto">
              Our platform offers everything you need to create and launch your own token on Uniswap v4
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {features.map((feature, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
                viewport={{ once: true, margin: "-100px" }}
                className="bg-background/40 backdrop-blur-sm border border-teal-500/10 hover:border-teal-500/30 rounded-lg p-6 transition-all duration-300 group"
              >
                <div className="rounded-md bg-teal-500/10 border border-teal-500/20 w-12 h-12 flex items-center justify-center mb-4 text-teal-500">
                  <feature.icon className="h-6 w-6" />
                </div>
                <h3 className="text-xl font-bold mb-2 text-teal-500">{feature.title}</h3>
                <p className="text-muted-foreground">{feature.description}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Recent Tokens Section */}
      <section className="py-16 border-y border-teal-500/10 backdrop-blur-sm bg-background/40">
        <div className="container mx-auto px-4">
          <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-12">
            <div>
              <Badge
                variant="outline"
                className="px-3 py-1 border-teal-500/50 bg-background/50 text-teal-500 backdrop-blur-sm mb-4"
              >
                <Zap className="h-3.5 w-3.5 mr-1" />
                Latest Launches
              </Badge>

              <h2 className="text-3xl font-bold mb-2 bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
                Recent Tokens
              </h2>

              <p className="text-muted-foreground">Check out the latest tokens created on our platform</p>
            </div>

            <div className="flex gap-2 mt-4 md:mt-0">
              <button
                onClick={() => setActiveTab("all")}
                className={`px-4 py-2 rounded-md transition-all ${activeTab === "all" ? "bg-teal-500/10 text-teal-500 border border-teal-500/20" : "text-muted-foreground hover:text-teal-500"}`}
              >
                All Launches
              </button>
              <button
                onClick={() => setActiveTab("dutch")}
                className={`px-4 py-2 rounded-md transition-all ${activeTab === "dutch" ? "bg-teal-500/10 text-teal-500 border border-teal-500/20" : "text-muted-foreground hover:text-teal-500"}`}
              >
                Dutch Auctions
              </button>
              <button
                onClick={() => setActiveTab("exponential")}
                className={`px-4 py-2 rounded-md transition-all ${activeTab === "exponential" ? "bg-teal-500/10 text-teal-500 border border-teal-500/20" : "text-muted-foreground hover:text-teal-500"}`}
              >
                Exponential
              </button>
            </div>
          </div>

          <motion.div
            className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
            variants={container}
            initial="hidden"
            whileInView="show"
            viewport={{ once: true, margin: "-100px" }}
          >
            {launches.slice(0, 6).map((launch) => (
              <motion.div key={launch.id} variants={item}>
                <Card className="overflow-hidden backdrop-blur-md bg-background/40 border border-teal-500/10 hover:border-teal-500/50 transition-all duration-300 hover:shadow-lg hover:shadow-teal-500/10">
                  <CardContent className="p-6">
                    <div className="flex justify-between items-start mb-4">
                      <div className="flex items-center space-x-2">
                        <motion.img
                          src={launch.logoUrl || "/placeholder.svg"}
                          alt={launch.name}
                          className="w-8 h-8 rounded-full cursor-pointer"
                          whileHover={{ scale: 1.2, rotate: 10 }}
                          onClick={() => setSelectedToken(launch.id)}
                        />
                        <div>
                          <h3 className="font-bold">{launch.name}</h3>
                          <p className="text-sm text-muted-foreground">{launch.ticker}</p>
                        </div>
                      </div>
                      <Badge
                        variant={
                          launch.status === "active"
                            ? "default"
                            : launch.status === "upcoming"
                              ? "outline"
                              : "secondary"
                        }
                        className={
                          launch.status === "active"
                            ? "bg-green-500/20 text-green-500 border-green-500/50"
                            : launch.status === "upcoming"
                              ? "bg-blue-500/20 text-blue-500 border-blue-500/50"
                              : "bg-teal-500/20 text-teal-500 border-teal-500/50"
                        }
                      >
                        {launch.status}
                      </Badge>
                    </div>

                    <p className="text-sm text-muted-foreground mb-4">{launch.description}</p>

                    <div className="space-y-4 mb-4">
                      <div className="flex justify-between text-sm">
                        <span className="text-muted-foreground">Progress</span>
                        <span>{launch.progress}%</span>
                      </div>
                      <Progress
                        value={launch.progress}
                        className="h-2 bg-background/50"
                        indicatorClassName={
                          launch.type === "dutch"
                            ? "bg-gradient-to-r from-teal-500 to-blue-500"
                            : "bg-gradient-to-r from-indigo-500 to-purple-500"
                        }
                      />
                    </div>

                    <div className="grid grid-cols-2 gap-4 text-sm mb-4">
                      <div>
                        <p className="text-muted-foreground">Type</p>
                        <p className="font-medium flex items-center">
                          {launch.type === "dutch" ? (
                            <>
                              Dutch Auction
                              <TrendingUp className="ml-1 h-3 w-3 text-teal-500" />
                            </>
                          ) : (
                            <>
                              Exponential
                              <Clock className="ml-1 h-3 w-3 text-indigo-500" />
                            </>
                          )}
                        </p>
                      </div>
                      <div>
                        <p className="text-muted-foreground">Ends in</p>
                        <p className="font-medium">
                          {formatDistanceToNow(new Date(launch.endTime), { addSuffix: true })}
                        </p>
                      </div>
                    </div>

                    <Link
                      to={launch.type === "dutch" ? `/dutch-auction/${launch.id}` : `/exponential-launch/${launch.id}`}
                      className="w-full"
                    >
                      <Button className="w-full group bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600">
                        View Details
                        <ArrowRight className="ml-2 h-4 w-4 group-hover:translate-x-1 transition-transform" />
                      </Button>
                    </Link>
                  </CardContent>
                </Card>
              </motion.div>
            ))}
          </motion.div>

          <div className="flex justify-center mt-8">
            <Link to="/dashboard">
              <Button variant="outline" className="border-teal-500/50 hover:border-teal-500 hover:bg-teal-500/10">
                View All Tokens
                <ChevronRight className="ml-2 h-4 w-4" />
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 relative">
        <div className="absolute inset-0 bg-gradient-radial from-teal-500/10 via-transparent to-transparent -z-10"></div>

        <div className="container mx-auto px-4">
          <div className="max-w-3xl mx-auto text-center">
            <h2 className="text-3xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
              Ready to Launch Your Token?
            </h2>

            <p className="text-xl text-muted-foreground mb-8">
              Join thousands of creators who have already launched their tokens on V4Forge
            </p>

            <Link to="/create">
              <Button
                size="lg"
                className="h-12 px-8 font-medium bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600"
              >
                Get Started Now
                <ArrowRight className="ml-2 h-4 w-4" />
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {selectedToken && <TokenModel tokenId={selectedToken} onClose={() => setSelectedToken(null)} />}
    </div>
  )
}

export default LandingPage
