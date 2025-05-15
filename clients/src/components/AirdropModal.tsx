"use client"

import { useState, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { X, CheckCircle, XCircle, ExternalLink, Copy, CheckCheck } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useAccount } from "wagmi"

interface AirdropModalProps {
  isOpen: boolean
  onClose: () => void
  status: "pending" | "success" | "error" | null
  txHash?: string
  tokenInfo?: any
  recipientCount: number
  airdropAmount: string
  error?: string
  chainExplorer?: string
}

export default function AirdropModal({
  isOpen,
  onClose,
  status,
  txHash,
  tokenInfo,
  recipientCount,
  airdropAmount,
  error,
}: AirdropModalProps) {
  const [copied, setCopied] = useState(false)
  const account = useAccount();
  const chainExplorer = account?.chain?.blockExplorers?.default?.url;

  const handleCopyTxHash = () => {
    if (txHash) {
      navigator.clipboard.writeText(txHash)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  // Close on escape key
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose()
    }
    window.addEventListener("keydown", handleEsc)
    return () => window.removeEventListener("keydown", handleEsc)
  }, [onClose])

  if (!isOpen) return null

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      >
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          transition={{ type: "spring", damping: 20, stiffness: 300 }}
          className="bg-background/80 backdrop-blur-xl border border-teal-500/30 rounded-xl w-full max-w-md overflow-hidden shadow-xl"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="relative p-6">
            <button
              onClick={onClose}
              className="absolute top-4 right-4 p-1 rounded-full hover:bg-teal-500/10 transition-colors"
            >
              <X className="h-5 w-5 text-teal-500" />
            </button>

            <div className="text-center mb-6">
              {status === "pending" ? (
                <div className="flex flex-col items-center">
                  <div className="h-16 w-16 rounded-full border-4 border-t-transparent border-teal-500 animate-spin mb-4"></div>
                  <h3 className="text-xl font-bold mb-2">Processing Airdrop</h3>
                  <p className="text-muted-foreground">Please wait while we process your transaction...</p>
                </div>
              ) : status === "success" ? (
                <div className="flex flex-col items-center">
                  <div className="h-16 w-16 rounded-full bg-teal-500/20 flex items-center justify-center mb-4">
                    <CheckCircle className="h-10 w-10 text-teal-500" />
                  </div>
                  <h3 className="text-xl font-bold mb-2">Airdrop Successful!</h3>
                  <p className="text-muted-foreground">Your tokens have been successfully distributed.</p>
                </div>
              ) : (
                <div className="flex flex-col items-center">
                  <div className="h-16 w-16 rounded-full bg-red-500/20 flex items-center justify-center mb-4">
                    <XCircle className="h-10 w-10 text-red-500" />
                  </div>
                  <h3 className="text-xl font-bold mb-2">Airdrop Failed</h3>
                  <p className="text-red-400">{error || "An error occurred during the airdrop process."}</p>
                </div>
              )}
            </div>

            {status !== "error" && (
              <div className="bg-black/30 rounded-lg p-4 mb-6">
                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div>
                    <p className="text-teal-500">Token</p>
                    <p className="font-medium">{tokenInfo?.symbol || "Unknown"}</p>
                  </div>
                  <div>
                    <p className="text-teal-500">Recipients</p>
                    <p className="font-medium">{recipientCount}</p>
                  </div>
                  <div>
                    <p className="text-teal-500">Amount per recipient</p>
                    <p className="font-medium">{airdropAmount}</p>
                  </div>
                  <div>
                    <p className="text-teal-500">Total amount</p>
                    <p className="font-medium">{Number(airdropAmount) * recipientCount}</p>
                  </div>
                </div>
              </div>
            )}

            {txHash && (
              <div className="mb-6">
                <p className="text-sm text-teal-500 mb-1">Transaction Hash</p>
                <div className="flex items-center bg-black/30 rounded-lg p-2 font-mono text-xs">
                  <div className="truncate flex-1">{txHash}</div>
                  <button
                    onClick={handleCopyTxHash}
                    className="ml-2 p-1 hover:bg-teal-500/10 rounded transition-colors"
                  >
                    {copied ? (
                      <CheckCheck className="h-4 w-4 text-teal-500" />
                    ) : (
                      <Copy className="h-4 w-4 text-teal-500" />
                    )}
                  </button>
                </div>
              </div>
            )}

            <div className="flex justify-end space-x-3">
              <Button variant="outline" onClick={onClose} className="border-teal-500/30 hover:bg-teal-500/10">
                Close
              </Button>

              {txHash && (
                <Button
                  className="bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600"
                  onClick={() => window.open(`${chainExplorer}/tx/${txHash}`, "_blank")}
                >
                  View on Explorer
                  <ExternalLink className="ml-2 h-4 w-4" />
                </Button>
              )}
            </div>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
