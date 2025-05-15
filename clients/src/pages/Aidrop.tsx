"use client"

import type React from "react"
import { useState, useEffect, useRef } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { AlertCircle, Copy, CheckCircle, Upload, ArrowRight, Info, Terminal, Code, Zap } from "lucide-react"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { useAccount, useChainId } from "wagmi"
import { toast } from "react-hot-toast"
import { readContract } from "@wagmi/core"
import { config } from "@/providers/Wagmi"
import { erc20Abi } from "@/utils/ERC20"
import { useTokenAirdrop } from "@/hooks/useTokenAirdrop"
import { formatUnits } from "viem"
import AirdropModal from "@/components/AirdropModal"

// Function to validate and count addresses
function parseAddressList(addressList: string) {
  if (!addressList.trim()) {
    return []
  }

  return addressList
    .split("\n")
    .map((addr) => addr.trim())
    .filter((addr) => addr.length >= 42 && addr.startsWith("0x"))
}

export default function AirdropPage() {
  const { address, isConnected } = useAccount()
  const account = useAccount()
  const symbol = account?.chain?.nativeCurrency?.symbol || "ETH"
  const chainId = useChainId()
  const [tokenAddress, setTokenAddress] = useState("")
  const [airdropAmount, setAirdropAmount] = useState("")
  const [addressList, setAddressList] = useState("")
  const [addressCount, setAddressCount] = useState(0)
  const [copied, setCopied] = useState(false)
  const [hoveredField, setHoveredField] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [isLoadingToken, setIsLoadingToken] = useState(false)
  const [tokenInfo, setTokenInfo] = useState<any>(null)
  const [tokenError, setTokenError] = useState<string | null>(null)
  const [terminalLines, setTerminalLines] = useState<string[]>([])
  const [terminalIndex, setTerminalIndex] = useState(0)
  const [isModalOpen, setIsModalOpen] = useState(false)

  // Connect the useTokenAirdrop hook
  const {
    performTokenAirdrop,
    isApproving,
    isDistributing,
    isProcessing,
    currentTxHash,
    // txReceipt,
    serviceFee,
    distributionStatus,
    clearDistributionStatus,
  } = useTokenAirdrop()

  // Open modal when distribution starts or status changes
  useEffect(() => {
    if (isDistributing || distributionStatus.status) {
      setIsModalOpen(true)
    }
  }, [isDistributing, distributionStatus])

  // Debounce token address changes
  const [debouncedTokenAddress, setDebouncedTokenAddress] = useState("")
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedTokenAddress(tokenAddress)
    }, 500) // 500ms delay

    return () => clearTimeout(timer)
  }, [tokenAddress])

  // Fetch actual token info instead of mock data
  useEffect(() => {
    async function fetchTokenInfo() {
      if (debouncedTokenAddress && debouncedTokenAddress.length === 42 && address) {
        setIsLoadingToken(true)
        setTokenError(null)

        try {
          // Get token name
          const name = await readContract(config, {
            address: debouncedTokenAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: "name",
          })

          // Get token symbol
          const symbol = await readContract(config, {
            address: debouncedTokenAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: "symbol",
          })

          // Get token decimals
          const decimals = await readContract(config, {
            address: debouncedTokenAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: "decimals",
          })

          // Get token balance
          const balance = await readContract(config, {
            address: debouncedTokenAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: "balanceOf",
            args: [address],
          })

          // Format balance with decimals
          const formattedBalance = Number.parseFloat(
            (Number(balance) / Math.pow(10, Number(decimals))).toString(),
          ).toLocaleString(undefined, { maximumFractionDigits: 2 })

          setTokenInfo({
            name,
            symbol,
            decimal: decimals,
            balance: formattedBalance,
          })
        } catch (error) {
          console.error("Error fetching token info:", error)
          setTokenError("Invalid token address or token not found")
          setTokenInfo(null)
        } finally {
          setIsLoadingToken(false)
        }
      }
    }

    fetchTokenInfo()
  }, [debouncedTokenAddress, address])

  // Terminal animation effect
  useEffect(() => {
    const lines = [
      "> Initializing V4Forge airdrop module...",
      "> Loading token interface from ABI...",
      "> Connecting to blockchain network...",
      "> Preparing distribution mechanism...",
      "> Validating token contract...",
      "> Airdrop module ready. Enter token details.",
    ]

    if (terminalIndex < lines.length) {
      const timer = setTimeout(() => {
        setTerminalLines((prev) => [...prev, lines[terminalIndex]])
        setTerminalIndex(terminalIndex + 1)
      }, 500)

      return () => clearTimeout(timer)
    }
  }, [terminalIndex])

  // Count addresses with debounce
  useEffect(() => {
    const timer = setTimeout(() => {
      const validAddresses = parseAddressList(addressList)
      setAddressCount(validAddresses.length)
    }, 300)

    return () => clearTimeout(timer)
  }, [addressList])

  // Monitor distribution status changes
  useEffect(() => {
    if (distributionStatus.status === "success") {
      toast.success(`Successfully airdropped tokens to ${addressCount} addresses`, {
        id: "distributionToast",
      })

      // Reset form on successful distribution after a delay
      const timer = setTimeout(() => {
        setTokenAddress("")
        setAirdropAmount("")
        setAddressList("")
      }, 5000) // Give user time to see the success state before reset

      return () => clearTimeout(timer)
    } else if (distributionStatus.status === "error") {
      toast.error(`Failed to send airdrop: ${distributionStatus.error || "Unknown error"}`, {
        id: "distributionToast",
      })
    }
  }, [distributionStatus, addressCount])

  const handleCopyExample = () => {
    const exampleAddresses =
      "0x690C65EB2e2dd321ACe41a9865Aea3fAa98be2A5\n0x429cB52eC6a7Fc28bC88431909Ae469977F6daCF\n0x0dD157808C204C97dE18b941e76bcAa20Cd0E806"

    navigator.clipboard.writeText(exampleAddresses)
    setAddressList(exampleAddresses)
    setCopied(true)

    setTimeout(() => setCopied(false), 2000)
  }

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (event) => {
      const content = event.target?.result
      if (typeof content === "string") {
        setAddressList(content)
      }
    }
    reader.readAsText(file)
  }

  // Handle close modal
  const handleCloseModal = () => {
    setIsModalOpen(false)
    // Only clear distribution status if not currently processing
    if (!isProcessing) {
      clearDistributionStatus()
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!isConnected) {
      toast.error("Please connect your wallet first")
      return
    }

    if (!tokenAddress || !airdropAmount || !addressList.trim() || !tokenInfo) {
      toast.error("Please fill in all required fields")
      return
    }

    const recipients = parseAddressList(addressList)

    if (recipients.length === 0) {
      toast.error("Please enter at least one valid recipient address")
      return
    }

    // Clear previous distribution status
    clearDistributionStatus()

    // Show loading toast
    toast.loading("Processing airdrop transaction...", { id: "airdropToast" })

    try {
      // Open modal right before starting the transaction
      setIsModalOpen(true)

      // Use the performTokenAirdrop function from the hook
      const result = await performTokenAirdrop(
        tokenAddress as `0x${string}`,
        tokenInfo.decimal,
        recipients as `0x${string}`[],
        airdropAmount,
      )

      if (!result.success) {
        toast.dismiss("airdropToast")
        toast.error(`Failed to send airdrop: ${result.error || "Unknown error"}`)
      }
    } catch (error: any) {
      toast.dismiss("airdropToast")
      toast.error(`Failed to send airdrop: ${error instanceof Error ? error.message : "Unknown error"}`)
    }
  }

  // Show terminal during initial load
  if (terminalIndex < 6) {
    return (
      <div className="min-h-[80vh] flex items-center justify-center">
        <Card className="w-full max-w-2xl bg-black border-teal-500/30">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-teal-500">
              <Terminal className="h-5 w-5" />
              V4Forge Terminal
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="font-mono text-sm bg-black text-teal-500 p-4 rounded-md h-64 overflow-hidden">
              {terminalLines.map((line, index) => (
                <div key={index} className="mb-2">
                  {line}
                </div>
              ))}
              <div className="inline-block h-4 w-2 bg-teal-500 animate-pulse ml-1"></div>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  // Determine the modal status based on current state
  const getModalStatus = () => {
    if (distributionStatus.status) {
      return distributionStatus.status
    }
    if (isApproving || isDistributing) {
      return "pending"
    }
    return null
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
            Token Airdrop
          </h1>
          <p className="text-muted-foreground">Distribute tokens to multiple addresses in one transaction</p>
        </div>

        <div className="flex items-center gap-3">
          <Button
            variant="outline"
            size="sm"
            className="border-teal-500/30 hover:border-teal-500 hover:bg-teal-500/10"
            onClick={() => window.location.reload()}
          >
            <Code className="h-4 w-4 mr-2" />
            Reset
          </Button>
        </div>
      </div>

      {/* Terminal Card */}
      <Card className="bg-black border-teal-500/30">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm flex items-center gap-2 text-teal-500">
            <Terminal className="h-4 w-4" />
            V4Forge Airdrop Terminal
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="font-mono text-xs bg-black text-teal-500 p-3 rounded-md h-24 overflow-auto">
            <div className="mb-1">
              &gt; {chainId === 84532 ? "Base" : chainId === 44787 ? "Celo" : "Ethereum"} Network:{" "}
              {isConnected ? "Connected" : "Not Connected"}
            </div>
            <div className="mb-1">&gt; Gas Price: 25 Gwei</div>
            <div className="mb-1">&gt; Airdrop Module: Ready</div>
            <div className="mb-1">
              &gt; Status: {isConnected ? "Wallet Connected" : "Waiting for wallet connection"}
              {isApproving && " - Approving tokens..."}
              {isDistributing && " - Distributing tokens..."}
              {currentTxHash && ` - TX: ${currentTxHash.slice(0, 6)}...${currentTxHash.slice(-4)}`}
            </div>
            <div className="inline-block h-4 w-2 bg-teal-500 animate-pulse ml-1"></div>
          </div>
        </CardContent>
      </Card>

      {/* Main Form */}
      <form onSubmit={handleSubmit}>
        <motion.div
          className="bg-black/50 border border-teal-500/30 rounded-xl shadow-xl overflow-hidden"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          <div className="p-6">
            {/* Token Address */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.1 }}
              className="mb-6"
            >
              <div className="flex items-center justify-between mb-2">
                <label className="block text-sm font-medium text-teal-500">
                  Token Address <span className="text-red-500">*</span>
                </label>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger>
                      <Info className="h-4 w-4 text-teal-500" />
                    </TooltipTrigger>
                    <TooltipContent className="bg-black border-teal-500/30 text-white">
                      <p className="text-xs max-w-xs">Enter the contract address of the token you want to airdrop</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <motion.div
                className="relative"
                onMouseEnter={() => setHoveredField("tokenAddress")}
                onMouseLeave={() => setHoveredField(null)}
              >
                <AnimatePresence>
                  {hoveredField === "tokenAddress" && (
                    <motion.span
                      className="absolute inset-0 bg-teal-500/10 rounded-xl z-0"
                      layoutId="hoverField"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.15 }}
                    />
                  )}
                </AnimatePresence>
                <Input
                  type="text"
                  value={tokenAddress}
                  onChange={(e) => setTokenAddress(e.target.value)}
                  placeholder="0x1728d6Ad90e84E24ee68fe68fD01014D9B8d7B3"
                  className="bg-background/50 border-teal-500/30 rounded-xl placeholder:text-muted-foreground focus:border-teal-500 transition-all duration-200 relative z-10"
                />
              </motion.div>
            </motion.div>

            {/* Token Info */}
            <AnimatePresence>
              {isLoadingToken ? (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  className="bg-background/50 border border-teal-500/30 rounded-xl p-4 mb-6"
                >
                  <div className="flex items-center justify-center">
                    <div className="h-5 w-5 rounded-full border-2 border-t-transparent border-teal-500 animate-spin mr-2"></div>
                    <span className="text-teal-500">Loading token information...</span>
                  </div>
                </motion.div>
              ) : tokenError ? (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  className="bg-background/50 border border-red-500/30 rounded-xl p-4 mb-6"
                >
                  <div className="flex items-center text-red-400">
                    <AlertCircle className="h-5 w-5 mr-2" />
                    <span>{tokenError}</span>
                  </div>
                </motion.div>
              ) : tokenInfo ? (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  className="bg-background/50 border border-teal-500/30 rounded-xl p-4 mb-6"
                >
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <div className="text-teal-500 text-sm">Name:</div>
                      <div className="text-white font-medium">{tokenInfo.name || "Unknown"}</div>
                    </div>
                    <div>
                      <div className="text-teal-500 text-sm">Symbol:</div>
                      <div className="text-white font-medium">{tokenInfo.symbol || "Unknown"}</div>
                    </div>
                    <div>
                      <div className="text-teal-500 text-sm">Decimal:</div>
                      <div className="text-white font-medium">{tokenInfo.decimal?.toString() || "0"}</div>
                    </div>
                    <div>
                      <div className="text-teal-500 text-sm">Balance:</div>
                      <div className="text-white font-medium">
                        {tokenInfo.balance} {tokenInfo.symbol}
                      </div>
                    </div>
                  </div>
                </motion.div>
              ) : null}
            </AnimatePresence>

            {/* Airdrop Amount */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.2 }}
              className="mb-6"
            >
              <div className="flex items-center justify-between mb-2">
                <label className="block text-sm font-medium text-teal-500">
                  Airdrop Amount <span className="text-red-500">*</span>
                </label>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger>
                      <Info className="h-4 w-4 text-teal-500" />
                    </TooltipTrigger>
                    <TooltipContent className="bg-black border-teal-500/30 text-white">
                      <p className="text-xs max-w-xs">Amount of tokens to send to each recipient address</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <motion.div
                className="relative"
                onMouseEnter={() => setHoveredField("airdropAmount")}
                onMouseLeave={() => setHoveredField(null)}
              >
                <AnimatePresence>
                  {hoveredField === "airdropAmount" && (
                    <motion.span
                      className="absolute inset-0 bg-teal-500/10 rounded-xl z-0"
                      layoutId="hoverField"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.15 }}
                    />
                  )}
                </AnimatePresence>
                <Input
                  type="text"
                  value={airdropAmount}
                  onChange={(e) => setAirdropAmount(e.target.value)}
                  placeholder="2000"
                  className="bg-background/50 border-teal-500/30 rounded-xl placeholder:text-muted-foreground focus:border-teal-500 transition-all duration-200 relative z-10"
                />
              </motion.div>
            </motion.div>

            {/* Address List */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.3 }}
              className="mb-6"
            >
              <div className="flex items-center justify-between mb-2">
                <label className="block text-sm font-medium text-teal-500">
                  Address List <span className="text-red-500">*</span>
                </label>
                <div className="flex space-x-2">
                  <motion.button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    className="text-teal-500 cursor-pointer hover:text-white hover:bg-teal-500/10 text-xs rounded-lg px-2 py-1 flex items-center transition-colors"
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                  >
                    <Upload className="h-3 w-3 mr-1" />
                    Import
                  </motion.button>
                  <input
                    type="file"
                    ref={fileInputRef}
                    onChange={handleFileUpload}
                    accept=".txt,.csv"
                    className="hidden"
                  />
                  <motion.button
                    type="button"
                    onClick={handleCopyExample}
                    className="text-teal-500 cursor-pointer hover:text-white hover:bg-teal-500/10 text-xs rounded-lg px-2 py-1 flex items-center transition-colors"
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                  >
                    {copied ? (
                      <>
                        <CheckCircle className="h-3 w-3 mr-1" />
                        Copied
                      </>
                    ) : (
                      <>
                        <Copy className="h-3 w-3 mr-1" />
                        Example
                      </>
                    )}
                  </motion.button>
                </div>
              </div>
              <motion.div
                className="relative"
                onMouseEnter={() => setHoveredField("addressList")}
                onMouseLeave={() => setHoveredField(null)}
              >
                <AnimatePresence>
                  {hoveredField === "addressList" && (
                    <motion.span
                      className="absolute inset-0 bg-teal-500/10 rounded-xl z-0"
                      layoutId="hoverField"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.15 }}
                    />
                  )}
                </AnimatePresence>
                <Textarea
                  value={addressList}
                  onChange={(e) => setAddressList(e.target.value)}
                  placeholder="Enter one address per line"
                  className="bg-background/50 border-teal-500/30 rounded-xl placeholder:text-muted-foreground focus:border-teal-500 transition-all duration-200 min-h-[120px] relative z-10 font-mono"
                />
              </motion.div>
              {addressCount > 0 && (
                <motion.div
                  initial={{ opacity: 0, y: 5 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="mt-2 text-xs text-teal-500 flex items-center"
                >
                  <CheckCircle className="h-3 w-3 mr-1 text-teal-500" />
                  {addressCount} valid address{addressCount !== 1 ? "es" : ""} found
                </motion.div>
              )}
            </motion.div>

            {/* Distribution Preview */}
            {addressCount > 0 && airdropAmount && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: "auto" }}
                exit={{ opacity: 0, height: 0 }}
                className="mb-6 bg-background/50 border border-teal-500/30 rounded-xl p-4"
              >
                <h3 className="text-sm font-medium text-teal-500 mb-3 flex items-center">
                  <Zap className="h-4 w-4 mr-2" />
                  Distribution Preview
                </h3>
                <div className="space-y-3">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Recipients</span>
                    <span>{addressCount} addresses</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Amount per recipient</span>
                    <span>{Number(airdropAmount).toLocaleString()} tokens</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Total tokens</span>
                    <span className="font-medium text-teal-500">
                      {!isNaN(Number(airdropAmount)) ? Number(Number(airdropAmount) * addressCount).toLocaleString() : 0} tokens
                    </span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Estimated gas</span>
                    <span>
                      ~{formatUnits(serviceFee, 18) || "0.00002"} {symbol}
                    </span>
                  </div>
                </div>
              </motion.div>
            )}

            {/* Transaction Status */}
            <AnimatePresence>
              {distributionStatus.status && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  className={`mb-6 bg-background/50 border ${distributionStatus.status === "success" ? "border-green-500/30" : "border-red-500/30"
                    } rounded-xl p-4`}
                >
                  <h3 className="text-sm font-medium mb-3 flex items-center">
                    {distributionStatus.status === "success" ? (
                      <>
                        <CheckCircle className="h-4 w-4 mr-2 text-green-500" />
                        <span className="text-green-500">Transaction Successful</span>
                      </>
                    ) : (
                      <>
                        <AlertCircle className="h-4 w-4 mr-2 text-red-500" />
                        <span className="text-red-500">Transaction Failed</span>
                      </>
                    )}
                  </h3>
                  {distributionStatus.txHash && (
                    <div className="text-sm break-all">
                      <span className="text-muted-foreground">Transaction Hash: </span>
                      <span>{distributionStatus.txHash}</span>
                    </div>
                  )}
                  {distributionStatus.error && (
                    <div className="text-sm text-red-400 mt-2">Error: {distributionStatus.error}</div>
                  )}
                </motion.div>
              )}
            </AnimatePresence>

            {/* Submit Button */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.4 }}
              className="flex flex-col md:flex-row justify-between items-center pt-6 border-t border-teal-500/30"
            >
              <div className="flex items-center mb-4 md:mb-0">
                <span className="text-teal-500">Total cost:</span>
                <span className="text-xl font-bold bg-gradient-to-r from-teal-500 to-blue-500 bg-clip-text text-transparent ml-2">
                  ~{formatUnits(serviceFee, 18) || "0.00002"} {symbol}
                </span>
              </div>
              <motion.button
                type="submit"
                disabled={!isConnected || isProcessing || !tokenAddress || !airdropAmount || addressCount === 0}
                className="bg-gradient-to-r cursor-pointer from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600 text-white rounded-xl px-8 py-4 h-auto font-medium transition-all duration-300 w-full md:w-auto shadow-lg shadow-teal-500/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                whileHover={{ scale: 1.03 }}
                whileTap={{ scale: 0.97 }}
              >
                {isProcessing ? (
                  <>
                    <div className="h-5 w-5 rounded-full border-2 border-t-transparent border-white animate-spin mr-2"></div>
                    {isApproving ? "Approving..." : "Processing..."}
                  </>
                ) : !isConnected ? (
                  "Connect Wallet"
                ) : (
                  <>
                    Send Airdrop
                    <ArrowRight className="ml-2 h-4 w-4" />
                  </>
                )}
              </motion.button>
            </motion.div>
          </div>
        </motion.div>
      </form>

      {/* Code Example */}
      <Card className="bg-black/50 border-teal-500/30 mt-8">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm flex items-center gap-2 text-teal-500">
            <Code className="h-4 w-4" />
            Airdrop Code Example
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="font-mono text-xs bg-black text-teal-500 p-3 rounded-md overflow-auto">
            <pre>{`// Perform token airdrop
async function airdropTokens() {
  const result = await forge.airdropTokens({
    tokenAddress: '0x1234567890123456789012345678901234567890',
    amount: '100',  // Amount per recipient
    recipients: [
      '0x690C65EB2e2dd321ACe41a9865Aea3fAa98be2A5',
      '0x429cB52eC6a7Fc28bC88431909Ae469977F6daCF',
      '0x0dD157808C204C97dE18b941e76bcAa20Cd0E806'
    ]
  });
  
  console.log(\`Airdrop completed: \${result.txHash}\`);
}

// Call the function
airdropTokens();`}</pre>
          </div>
        </CardContent>
      </Card>

      {/* Modal Component */}
      <AirdropModal
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        status={getModalStatus()}
        txHash={distributionStatus.txHash as `0x${string}`}
        tokenInfo={tokenInfo}
        recipientCount={addressCount}
        airdropAmount={!isNaN(Number(airdropAmount)) ? (Number(airdropAmount) * addressCount).toString() : "0"}
      />
    </div>
  )
}
