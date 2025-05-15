"use client"

import { useEffect, useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { mockLaunches } from "@/lib/mock-data"
import { X } from 'lucide-react'
import { Button } from "./ui/button"
import { Link } from "react-router-dom"

interface TokenModelProps {
  tokenId: string
  onClose: () => void
}

export function TokenModel({ tokenId, onClose }: TokenModelProps) {
  const [token, setToken] = useState<any>(null)

  useEffect(() => {
    const foundToken = mockLaunches.find((t) => t.id === tokenId)
    if (foundToken) {
      setToken(foundToken)
    }
  }, [tokenId])

  if (!token) return null

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
          className="bg-background/80 backdrop-blur-xl border border-border/50 rounded-xl w-full max-w-2xl overflow-hidden shadow-xl"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="relative h-64">
            <div className="relative h-64 flex items-center justify-center bg-gradient-to-br from-teal-500/20 to-blue-500/20 rounded-t-xl">
              <div className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
                {token.name}
              </div>
              <button
                onClick={onClose}
                className="absolute top-4 right-4 p-2 rounded-full bg-background/20 backdrop-blur-md hover:bg-background/40 transition-colors"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          </div>

          <div className="p-6">
            <h2 className="text-2xl font-bold mb-2 bg-clip-text text-transparent bg-gradient-to-r from-teal-500 to-blue-500">
              {token.name}
            </h2>
            <p className="text-muted-foreground mb-4">{token.description}</p>

            <div className="grid grid-cols-2 gap-4 mb-6">
              <div>
                <p className="text-sm text-muted-foreground">Current Price</p>
                <p className="font-medium">${token.currentPrice.toFixed(4)}</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground">Progress</p>
                <p className="font-medium">{token.progress}% sold</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground">Type</p>
                <p className="font-medium">{token.type === "dutch" ? "Dutch Auction" : "Exponential Launch"}</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground">Status</p>
                <p className="font-medium capitalize">{token.status}</p>
              </div>
            </div>

            <div className="flex justify-end space-x-3">
              <Button variant="outline" onClick={onClose}>
                Close
              </Button>
              <Link to={token.type === "dutch" ? `/dutch-auction/${token.id}` : `/exponential-launch/${token.id}`}>
                <Button className="bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600">
                  View Details
                </Button>
              </Link>
            </div>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
