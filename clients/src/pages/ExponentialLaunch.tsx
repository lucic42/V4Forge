import type React from "react"

import { useState, useEffect } from "react"
import { useParams, useNavigate } from "react-router-dom"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Progress } from "@/components/ui/progress"
import { ArrowDown, Clock, ExternalLink, Info } from "lucide-react"
import { mockLaunches } from "@/lib/mock-data"
import { formatDistanceToNow } from "date-fns"
import { useAccount } from "wagmi"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import PriceChart from "@/components/PriceChart"
import { motion } from "framer-motion"
import { toast } from "react-hot-toast"
import ConnectWallet from "@/components/ConnectButton"
import TransactionModal, { type TransactionStatus } from "@/components/TransactionModal"

const ExponentialLaunch = () => {
  const navigate = useNavigate()
  const { id } = useParams()
  const { isConnected } = useAccount()
  const [launch, setLaunch] = useState<any>(null)
  const [inputAmount, setInputAmount] = useState("")
  const [outputAmount, setOutputAmount] = useState("")
  const [currentPrice, setCurrentPrice] = useState(0)
  const [isLoading, setIsLoading] = useState(false)

  // Transaction modal state
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [transactionStatus, setTransactionStatus] = useState<TransactionStatus>(null)
  const [transactionHash, setTransactionHash] = useState("")

  useEffect(() => {
    // Find the launch with the matching id
    const foundLaunch = mockLaunches.find((l) => l.id === id)
    if (foundLaunch) {
      setLaunch(foundLaunch)

      // Calculate current price based on exponential formula
      // In a real implementation, this would come from the contract
      const progressRatio = foundLaunch.progress / 100

      // Exponential: price increases as more tokens are sold
      const newPrice = foundLaunch.initialPrice * Math.exp(progressRatio * 2.3) // 2.3 is roughly ln(10)
      setCurrentPrice(newPrice)
    }
  }, [id])

  useEffect(() => {
    // Calculate output amount based on input and current price
    if (inputAmount && !isNaN(Number.parseFloat(inputAmount))) {
      const output = Number.parseFloat(inputAmount) / currentPrice
      setOutputAmount(output.toFixed(6))
    } else {
      setOutputAmount("")
    }
  }, [inputAmount, currentPrice])

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setInputAmount(e.target.value)
  }

  const handleOutputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setOutputAmount(e.target.value)
    if (e.target.value && !isNaN(Number.parseFloat(e.target.value))) {
      const input = Number.parseFloat(e.target.value) * currentPrice
      setInputAmount(input.toFixed(6))
    } else {
      setInputAmount("")
    }
  }

  const handleParticipate = () => {
    if (!isConnected) {
      toast.error("Please connect your wallet first")
      return
    }

    setIsLoading(true)
    setIsModalOpen(true)
    setTransactionStatus("pending")

    // Simulate transaction
    setTimeout(() => {
      // Generate a mock transaction hash
      const mockTxHash = "0x" + Array.from({ length: 64 }, () => Math.floor(Math.random() * 16).toString(16)).join("")
      setTransactionHash(mockTxHash)
      setTransactionStatus("success")
      setIsLoading(false)
    }, 3000)
  }

  const handleCloseModal = () => {
    setIsModalOpen(false)
    if (transactionStatus === "success") {
      setInputAmount("")
      setOutputAmount("")
    }
  }

  const handleViewTokenDetails = () => {
    navigate(`/token/${id}`)
  }

  if (!launch) {
    return <div className="flex justify-center items-center h-64">Loading...</div>
  }

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <img src={launch.logoUrl || "/placeholder.svg"} alt={launch.name} className="w-10 h-10 rounded-full" />
          <div>
            <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
              {launch.name} Exponential Launch
            </h1>
            <p className="text-muted-foreground">{launch.ticker} Token Launch</p>
          </div>
        </div>
        <a href={launch.website} target="_blank" rel="noopener noreferrer">
          <Button
            variant="outline"
            size="sm"
            className="flex items-center gap-1 border-teal-500/50 hover:border-teal-500 hover:bg-teal-500/10"
          >
            Website <ExternalLink className="h-3 w-3" />
          </Button>
        </a>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="md:col-span-2 backdrop-blur-md bg-background/40 border border-teal-500/30">
          <CardHeader>
            <CardTitle>Exponential Launch Details</CardTitle>
            <CardDescription>Price increases as more tokens are sold</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Progress</span>
                <span>{launch.progress}% sold</span>
              </div>
              <Progress
                value={launch.progress}
                className="h-2 bg-background/50"
                indicatorClassName="bg-gradient-to-r from-teal-500 to-blue-500"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Initial Price</p>
                <p className="font-medium">${launch.initialPrice.toFixed(4)} per token</p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Current Price</p>
                <p className="font-medium text-green-600 dark:text-green-400">${currentPrice.toFixed(4)} per token</p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Total Supply</p>
                <p className="font-medium">
                  {launch.totalSupply.toLocaleString()} {launch.ticker}
                </p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Remaining</p>
                <p className="font-medium">
                  {(launch.totalSupply * (1 - launch.progress / 100)).toLocaleString()} {launch.ticker}
                </p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Sale Ends</p>
                <p className="font-medium flex items-center">
                  <Clock className="mr-1 h-3 w-3" />
                  {formatDistanceToNow(new Date(launch.endTime), { addSuffix: true })}
                </p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Emission Rate</p>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger className="flex items-center font-medium">
                      {launch.emissionRate} tokens/sec
                      <Info className="ml-1 h-3 w-3" />
                    </TooltipTrigger>
                    <TooltipContent className="backdrop-blur-md bg-background/80 border border-teal-500/30">
                      <p className="max-w-xs">The rate at which tokens are made available for purchase</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
            </div>

            <div className="pt-4">
              <h3 className="font-medium mb-3">Price History</h3>
              <div className="h-64">
                <PriceChart type="exponential" startPrice={launch.initialPrice} endPrice={currentPrice} />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="backdrop-blur-md bg-background/40 border border-teal-500/30">
          <CardHeader>
            <CardTitle>Participate</CardTitle>
            <CardDescription>Purchase tokens at the current price</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="input-amount">You Pay</Label>
              <div className="flex items-center space-x-2">
                <Input
                  id="input-amount"
                  type="number"
                  placeholder="0.0"
                  value={inputAmount}
                  onChange={handleInputChange}
                  className="bg-background/50 border-teal-500/30 focus:border-teal-500/50 focus:ring-teal-500/20"
                />
                <div className="bg-teal-500/10 text-teal-500 border border-teal-500/20 px-3 py-2 rounded-md font-medium">
                  USDC
                </div>
              </div>
            </div>

            <div className="flex justify-center my-2">
              <motion.div animate={{ y: [0, 5, 0] }} transition={{ repeat: Number.POSITIVE_INFINITY, duration: 1.5 }}>
                <ArrowDown className="text-muted-foreground" />
              </motion.div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="output-amount">You Receive</Label>
              <div className="flex items-center space-x-2">
                <Input
                  id="output-amount"
                  type="number"
                  placeholder="0.0"
                  value={outputAmount}
                  onChange={handleOutputChange}
                  className="bg-background/50 border-teal-500/30 focus:border-teal-500/50 focus:ring-teal-500/20"
                />
                <div className="bg-teal-500/10 text-teal-500 border border-teal-500/20 px-3 py-2 rounded-md font-medium">
                  {launch.ticker}
                </div>
              </div>
            </div>

            <div className="pt-2 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Current Price</span>
                <span>${currentPrice.toFixed(4)} per token</span>
              </div>
              <div className="flex justify-between mt-1">
                <span className="text-muted-foreground">Dynamic Fee</span>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger className="flex items-center">
                      {launch.dynamicFee}%
                      <Info className="ml-1 h-3 w-3" />
                    </TooltipTrigger>
                    <TooltipContent className="backdrop-blur-md bg-background/80 border border-teal-500/30">
                      <p className="max-w-xs">This fee decreases over time to discourage early selling</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
            </div>
          </CardContent>
          <CardFooter>
            {isConnected ? (
              <Button
                className="w-full bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600"
                onClick={handleParticipate}
                disabled={isLoading || !inputAmount || Number(inputAmount) <= 0}
              >
                {isLoading ? (
                  <>
                    <span className="animate-spin mr-2">⟳</span>
                    Processing...
                  </>
                ) : (
                  "Participate in Launch"
                )}
              </Button>
            ) : (
              <div className="w-full flex justify-center">
                <ConnectWallet />
              </div>
            )}
          </CardFooter>
        </Card>
      </div>

      <Card className="backdrop-blur-md bg-background/40 border border-teal-500/30">
        <CardHeader>
          <CardTitle>About {launch.name}</CardTitle>
        </CardHeader>
        <CardContent>
          <p>{launch.longDescription}</p>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
            {launch.socialLinks.map((link: any) => (
              <a
                key={link.name}
                href={link.url}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center space-x-2 text-sm hover:underline group"
              >
                <span>{link.name}</span>
                <ExternalLink className="h-3 w-3 group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
              </a>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Transaction Modal */}
      <TransactionModal
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        status={transactionStatus}
        title={transactionStatus === "pending" ? "Processing Transaction" : "Transaction Successful"}
        description={
          transactionStatus === "pending"
            ? "Please wait while we process your transaction..."
            : `Successfully purchased ${outputAmount} ${launch.ticker} tokens!`
        }
        txHash={transactionHash}
        details={[
          { label: "Token", value: launch.ticker },
          { label: "Amount", value: outputAmount },
          { label: "Price", value: `$${currentPrice.toFixed(4)}` },
          { label: "Total Cost", value: `${inputAmount} USDC` },
        ]}
        actionLabel="View Token Details"
        onAction={handleViewTokenDetails}
      />
    </div>
  )
}

export default ExponentialLaunch
