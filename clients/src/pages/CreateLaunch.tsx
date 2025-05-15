import type React from "react"

import { useState } from "react"
import { useNavigate } from "react-router-dom"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useAccount } from "wagmi"
import { toast } from "react-hot-toast"
import { Info, TrendingUp, Clock, ArrowDown, ArrowUp } from "lucide-react"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import { motion } from "framer-motion"
import ConnectWallet from "@/components/ConnectButton"
import TransactionModal, { type TransactionStatus } from "@/components/TransactionModal"

const CreateLaunch = () => {
  const navigate = useNavigate()
  const { isConnected } = useAccount()
  const [activeTab, setActiveTab] = useState("dutch")
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Transaction modal state
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [transactionStatus, setTransactionStatus] = useState<TransactionStatus>(null)
  const [transactionHash, setTransactionHash] = useState("")

  const [formData, setFormData] = useState({
    name: "",
    ticker: "",
    description: "",
    website: "",
    totalSupply: "",
    initialPrice: "",
    // Dutch auction specific
    decayConstant: "",
    salePeriod: "",
    // Exponential specific
    emissionRate: "",
    dynamicFee: "",
  })

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setFormData((prev) => ({ ...prev, [name]: value }))
  }

  const handleSelectChange = (name: string, value: string) => {
    setFormData((prev) => ({ ...prev, [name]: value }))
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    if (!isConnected) {
      toast.error("Please connect your wallet first")
      return
    }

    // Validate form
    if (!formData.name || !formData.ticker || !formData.totalSupply || !formData.initialPrice) {
      toast.error("Please fill in all required fields")
      return
    }

    setIsSubmitting(true)
    setIsModalOpen(true)
    setTransactionStatus("pending")

    // Simulate transaction
    setTimeout(() => {
      // Generate a mock transaction hash
      const mockTxHash = "0x" + Array.from({ length: 64 }, () => Math.floor(Math.random() * 16).toString(16)).join("")
      setTransactionHash(mockTxHash)
      setTransactionStatus("success")
      setIsSubmitting(false)
    }, 3000)
  }

  const handleCloseModal = () => {
    setIsModalOpen(false)
    if (transactionStatus === "success") {
      // Navigate to dashboard
      navigate("/dashboard")
    }
  }

  const handleViewDashboard = () => {
    navigate("/dashboard")
  }

  return (
    <div className="max-w-3xl mx-auto">
      <motion.h1
        className="text-3xl font-bold mb-6 bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500"
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        Create Token Launch
      </motion.h1>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.1 }}
      >
        <Tabs defaultValue="dutch" onValueChange={setActiveTab}>
          <TabsList className="grid grid-cols-2 mb-6 bg-background/50 backdrop-blur-sm border border-border/50">
            <TabsTrigger value="dutch" className="relative">
              <div className="flex items-center gap-2">
                <TrendingUp className="h-4 w-4" />
                Dutch Auction
              </div>
            </TabsTrigger>
            <TabsTrigger value="exponential" className="relative">
              <div className="flex items-center gap-2">
                <Clock className="h-4 w-4" />
                Exponential Launch
              </div>
            </TabsTrigger>
          </TabsList>

          {/* Launch Type Explanation */}
          <Card className="mb-6 backdrop-blur-md bg-background/40 border border-teal-500/10">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                {activeTab === "dutch" ? (
                  <>
                    <TrendingUp className="h-5 w-5 text-teal-500" />
                    Dutch Auction Mechanism
                  </>
                ) : (
                  <>
                    <Clock className="h-5 w-5 text-teal-500" />
                    Exponential Launch Mechanism
                  </>
                )}
              </CardTitle>
              <CardDescription>
                {activeTab === "dutch"
                  ? "In a Dutch auction, the price starts high and decreases over time until all tokens are sold."
                  : "In an exponential launch, the price starts low and increases as more tokens are purchased."}
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="flex flex-col md:flex-row gap-6">
                <div className="flex-1">
                  <div className="h-40 bg-gradient-to-br from-teal-500/10 to-blue-500/10 rounded-lg mb-4 flex items-center justify-center relative overflow-hidden">
                    {activeTab === "dutch" ? (
                      <>
                        <div className="absolute top-4 left-4 text-teal-500 font-bold">High Price</div>
                        <ArrowDown className="h-8 w-8 text-teal-500 animate-bounce" />
                        <div className="absolute bottom-4 right-4 text-teal-500 font-bold">Low Price</div>
                      </>
                    ) : (
                      <>
                        <div className="absolute bottom-4 left-4 text-teal-500 font-bold">Low Price</div>
                        <ArrowUp className="h-8 w-8 text-teal-500 animate-bounce" />
                        <div className="absolute top-4 right-4 text-teal-500 font-bold">High Price</div>
                      </>
                    )}
                  </div>
                </div>
                <div className="flex-1">
                  <h3 className="text-lg font-medium mb-2 text-teal-500">Key Benefits:</h3>
                  <ul className="space-y-2 text-sm">
                    {activeTab === "dutch" ? (
                      <>
                        <li className="flex items-start gap-2">
                          <div className="rounded-full bg-teal-500/20 p-1 mt-0.5">
                            <div className="h-1.5 w-1.5 rounded-full bg-teal-500"></div>
                          </div>
                          <span>Finds the market's true price through price discovery</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <div className="rounded-full bg-teal-500/20 p-1 mt-0.5">
                            <div className="h-1.5 w-1.5 rounded-full bg-teal-500"></div>
                          </div>
                          <span>Incentivizes early participation as price decreases over time</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <div className="rounded-full bg-teal-500/20 p-1 mt-0.5">
                            <div className="h-1.5 w-1.5 rounded-full bg-teal-500"></div>
                          </div>
                          <span>Reduces FOMO and prevents price manipulation</span>
                        </li>
                      </>
                    ) : (
                      <>
                        <li className="flex items-start gap-2">
                          <div className="rounded-full bg-teal-500/20 p-1 mt-0.5">
                            <div className="h-1.5 w-1.5 rounded-full bg-teal-500"></div>
                          </div>
                          <span>Rewards early adopters with lower entry prices</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <div className="rounded-full bg-teal-500/20 p-1 mt-0.5">
                            <div className="h-1.5 w-1.5 rounded-full bg-teal-500"></div>
                          </div>
                          <span>Creates natural price discovery as demand increases</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <div className="rounded-full bg-teal-500/20 p-1 mt-0.5">
                            <div className="h-1.5 w-1.5 rounded-full bg-teal-500"></div>
                          </div>
                          <span>Prevents large buyers from acquiring all tokens at once</span>
                        </li>
                      </>
                    )}
                  </ul>
                </div>
              </div>
            </CardContent>
          </Card>

          <form onSubmit={handleSubmit}>
            <Card className="backdrop-blur-md bg-background/40 border border-teal-500/10 mb-6">
              <CardHeader>
                <CardTitle>Token Information</CardTitle>
                <CardDescription>Basic information about your token</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="name">Token Name *</Label>
                    <Input
                      id="name"
                      name="name"
                      placeholder="My Token"
                      value={formData.name}
                      onChange={handleChange}
                      required
                      className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="ticker">Token Symbol *</Label>
                    <Input
                      id="ticker"
                      name="ticker"
                      placeholder="TKN"
                      value={formData.ticker}
                      onChange={handleChange}
                      required
                      className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="description">Description</Label>
                  <Textarea
                    id="description"
                    name="description"
                    placeholder="Describe your token and its use case"
                    value={formData.description}
                    onChange={handleChange}
                    rows={3}
                    className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="website">Website</Label>
                  <Input
                    id="website"
                    name="website"
                    placeholder="https://mytoken.com"
                    value={formData.website}
                    onChange={handleChange}
                    className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="totalSupply">Total Supply *</Label>
                    <Input
                      id="totalSupply"
                      name="totalSupply"
                      type="number"
                      placeholder="1000000"
                      value={formData.totalSupply}
                      onChange={handleChange}
                      required
                      className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="initialPrice">Initial Price (USDC) *</Label>
                    <Input
                      id="initialPrice"
                      name="initialPrice"
                      type="number"
                      placeholder="0.001"
                      value={formData.initialPrice}
                      onChange={handleChange}
                      required
                      className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                    />
                  </div>
                </div>
              </CardContent>
            </Card>

            <TabsContent value="dutch" className="mt-0 p-0">
              <Card className="backdrop-blur-md bg-background/40 border border-teal-500/10">
                <CardHeader>
                  <CardTitle>Dutch Auction Parameters</CardTitle>
                  <CardDescription>Configure your Dutch auction parameters</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <div className="flex items-center space-x-2">
                        <Label htmlFor="decayConstant">Decay Constant *</Label>
                        <TooltipProvider>
                          <Tooltip>
                            <TooltipTrigger>
                              <Info className="h-4 w-4 text-muted-foreground" />
                            </TooltipTrigger>
                            <TooltipContent className="backdrop-blur-md bg-background/80 border border-border/50">
                              <p className="max-w-xs">
                                Controls how quickly the price decreases. Higher values mean faster price decrease.
                                <br />
                                <br />
                                Recommended: 0.1 - 0.3
                              </p>
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      </div>
                      <Input
                        id="decayConstant"
                        name="decayConstant"
                        type="number"
                        placeholder="0.1"
                        value={formData.decayConstant}
                        onChange={handleChange}
                        required
                        className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="salePeriod">Sale Period (days) *</Label>
                      <Input
                        id="salePeriod"
                        name="salePeriod"
                        type="number"
                        placeholder="7"
                        value={formData.salePeriod}
                        onChange={handleChange}
                        required
                        className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                      />
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="exponential" className="mt-0 p-0">
              <Card className="backdrop-blur-md bg-background/40 border border-teal-500/10">
                <CardHeader>
                  <CardTitle>Exponential Launch Parameters</CardTitle>
                  <CardDescription>Configure your exponential launch parameters</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <div className="flex items-center space-x-2">
                        <Label htmlFor="emissionRate">Emission Rate *</Label>
                        <TooltipProvider>
                          <Tooltip>
                            <TooltipTrigger>
                              <Info className="h-4 w-4 text-muted-foreground" />
                            </TooltipTrigger>
                            <TooltipContent className="backdrop-blur-md bg-background/80 border border-border/50">
                              <p className="max-w-xs">
                                The rate at which tokens are made available for purchase (tokens per second).
                                <br />
                                <br />
                                Higher values make more tokens available faster, potentially slowing price increases.
                              </p>
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      </div>
                      <Input
                        id="emissionRate"
                        name="emissionRate"
                        type="number"
                        placeholder="10"
                        value={formData.emissionRate}
                        onChange={handleChange}
                        required
                        className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20"
                      />
                    </div>
                    <div className="space-y-2">
                      <div className="flex items-center space-x-2">
                        <Label htmlFor="dynamicFee">Initial Dynamic Fee (%) *</Label>
                        <TooltipProvider>
                          <Tooltip>
                            <TooltipTrigger>
                              <Info className="h-4 w-4 text-muted-foreground" />
                            </TooltipTrigger>
                            <TooltipContent className="backdrop-blur-md bg-background/80 border border-border/50">
                              <p className="max-w-xs">
                                Initial fee applied to sellers. This fee decreases over time to discourage early selling
                                and protect early investors.
                              </p>
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      </div>
                      <Select onValueChange={(value) => handleSelectChange("dynamicFee", value)} defaultValue="10">
                        <SelectTrigger className="bg-background/50 border-border/50 focus:border-teal-500/50 focus:ring-teal-500/20">
                          <SelectValue placeholder="Select fee percentage" />
                        </SelectTrigger>
                        <SelectContent className="backdrop-blur-md bg-background/80 border border-border/50">
                          <SelectItem value="5">5%</SelectItem>
                          <SelectItem value="10">10%</SelectItem>
                          <SelectItem value="15">15%</SelectItem>
                          <SelectItem value="20">20%</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            <motion.div
              className="mt-6"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.3 }}
            >
              {isConnected ? (
                <Button
                  type="submit"
                  className="w-full cursor-pointer bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600"
                  disabled={isSubmitting}
                >
                  {isSubmitting ? (
                    <>
                      <span className="animate-spin mr-2">⟳</span>
                      Creating Launch...
                    </>
                  ) : (
                    "Create Launch"
                  )}
                </Button>
              ) : (
                <div className="flex justify-center">
                  <ConnectWallet />
                </div>
              )}
            </motion.div>
          </form>
        </Tabs>
      </motion.div>

      {/* Transaction Modal */}
      <TransactionModal
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        status={transactionStatus}
        title={transactionStatus === "pending" ? "Creating Token Launch" : "Token Launch Created"}
        description={
          transactionStatus === "pending"
            ? "Please wait while we create your token launch..."
            : `Successfully created ${formData.name} (${formData.ticker}) token launch!`
        }
        txHash={transactionHash}
        details={[
          { label: "Token Name", value: formData.name },
          { label: "Token Symbol", value: formData.ticker },
          { label: "Total Supply", value: formData.totalSupply },
          { label: "Initial Price", value: `$${formData.initialPrice}` },
          { label: "Launch Type", value: activeTab === "dutch" ? "Dutch Auction" : "Exponential Launch" },
        ]}
        actionLabel="View Dashboard"
        onAction={handleViewDashboard}
      />
    </div>
  )
}

export default CreateLaunch
