import { useState, useEffect } from "react"
import { Link } from "react-router-dom"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Progress } from "@/components/ui/progress"
import { ArrowUpRight, Clock, TrendingUp } from 'lucide-react'
import { mockLaunches } from "@/lib/mock-data"
import { formatDistanceToNow } from "date-fns"
import { motion } from "framer-motion"
import { TokenModel } from "@/components/TokenModel"

const Dashboard = () => {
  const [activeTab, setActiveTab] = useState("all")
  const [launches, setLaunches] = useState(mockLaunches)
  const [selectedToken, setSelectedToken] = useState<string | null>(null)

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

  return (
    <div className="space-y-6">
      <motion.div
        className="flex flex-col space-y-2"
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <h1 className="text-4xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
          V4Forge Launchpad
        </h1>
        <p className="text-muted-foreground">Launch and participate in Uniswap V4 token sales</p>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2, duration: 0.5 }}
      >
        <Tabs defaultValue="all" onValueChange={setActiveTab}>
          <TabsList className="bg-background/50 backdrop-blur-sm border border-border/50">
            <TabsTrigger value="all">All Launches</TabsTrigger>
            <TabsTrigger value="dutch">Dutch Auctions</TabsTrigger>
            <TabsTrigger value="exponential">Exponential Launches</TabsTrigger>
            <TabsTrigger value="completed">Completed</TabsTrigger>
          </TabsList>

          <TabsContent value={activeTab} className="mt-6">
            <motion.div
              className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
              variants={container}
              initial="hidden"
              animate="show"
            >
              {launches.map((launch) => (
                <motion.div key={launch.id} variants={item}>
                  <Card className="overflow-hidden backdrop-blur-md bg-background/40 border border-border/50 hover:border-teal-500/50 transition-all duration-300 hover:shadow-lg hover:shadow-teal-500/10">
                    <CardHeader className="pb-3">
                      <div className="flex justify-between items-start">
                        <div className="flex items-center space-x-2">
                          <motion.img
                            src={launch.logoUrl || "/placeholder.svg"}
                            alt={launch.name}
                            className="w-8 h-8 rounded-full cursor-pointer"
                            whileHover={{ scale: 1.2, rotate: 10 }}
                            onClick={() => setSelectedToken(launch.id)}
                          />
                          <CardTitle>{launch.name}</CardTitle>
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
                      <CardDescription>{launch.description}</CardDescription>
                    </CardHeader>
                    <CardContent className="pb-3">
                      <div className="space-y-4">
                        <div className="flex justify-between text-sm">
                          <span className="text-muted-foreground">Progress</span>
                          <span className="font-medium">{launch.progress}%</span>
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

                        <div className="grid grid-cols-2 gap-4 text-sm">
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
                      </div>
                    </CardContent>
                    <CardFooter>
                      <Link
                        to={
                          launch.type === "dutch" ? `/dutch-auction/${launch.id}` : `/exponential-launch/${launch.id}`
                        }
                        className="w-full"
                      >
                        <Button className="w-full group bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600">
                          View Details
                          <ArrowUpRight className="ml-2 h-4 w-4 group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
                        </Button>
                      </Link>
                    </CardFooter>
                  </Card>
                </motion.div>
              ))}
            </motion.div>
          </TabsContent>
        </Tabs>
      </motion.div>

      {selectedToken && <TokenModel tokenId={selectedToken} onClose={() => setSelectedToken(null)} />}
    </div>
  )
}

export default Dashboard
