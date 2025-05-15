import { useState, useEffect, useRef } from "react"
import { Terminal, ArrowRight, CheckCircle, Code, AlertCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Link } from "react-router-dom"

// Define the structure of a terminal line
interface TerminalLine {
  id: string // Changed to string for more unique keys
  type: "input" | "output" | "success" | "error" | "info"
  content: string
}

export default function TerminalShowcase() {
  // State for displayed lines and current typing state
  const [displayedLines, setDisplayedLines] = useState<TerminalLine[]>([])
  const [currentTypingLine, setCurrentTypingLine] = useState<TerminalLine | null>(null)
  const [typedContent, setTypedContent] = useState("")
  const [isComplete, setIsComplete] = useState(false)
  const terminalRef = useRef<HTMLDivElement>(null)
  const processedLinesRef = useRef<Set<string>>(new Set()) // Track processed lines

  // Predefined sequence of lines to display
  const terminalScript: TerminalLine[] = [
    { id: "info-1", type: "info", content: "Welcome to V4Forge Terminal. Type 'help' to see available commands." },
    { id: "input-1", type: "input", content: "create-token" },
    { id: "info-2", type: "info", content: "Initializing token creation wizard..." },
    { id: "info-3", type: "info", content: "Please provide the following information:" },
    { id: "input-2", type: "input", content: "name: CyberToken" },
    { id: "output-1", type: "output", content: "Token name set to 'CyberToken'" },
    { id: "input-3", type: "input", content: "symbol: CYBER" },
    { id: "output-2", type: "output", content: "Token symbol set to 'CYBER'" },
    { id: "input-4", type: "input", content: "supply: 1000000" },
    { id: "output-3", type: "output", content: "Total supply set to 1,000,000 CYBER" },
    { id: "input-5", type: "input", content: "launch-type: dutch-auction" },
    { id: "info-4", type: "info", content: "Configuring Dutch Auction parameters..." },
    { id: "input-6", type: "input", content: "initial-price: 0.1" },
    { id: "output-4", type: "output", content: "Initial price set to $0.1 per token" },
    { id: "input-7", type: "input", content: "decay-constant: 0.15" },
    { id: "output-5", type: "output", content: "Decay constant set to 0.15" },
    { id: "input-8", type: "input", content: "duration: 7 days" },
    { id: "output-6", type: "output", content: "Auction duration set to 7 days" },
    { id: "info-5", type: "info", content: "Generating smart contract..." },
    { id: "info-6", type: "info", content: "Deploying to Ethereum network..." },
    { id: "success-1", type: "success", content: "Success! CyberToken (CYBER) has been created and deployed." },
    { id: "info-7", type: "info", content: "Contract address: 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9" },
    { id: "info-8", type: "info", content: "Dutch Auction will start in 24 hours." },
    { id: "error-1", type: "error", content: "Warning: Make sure to have enough ETH for gas fees." },
    { id: "info-9", type: "info", content: "Type 'dashboard' to view your token." },
    { id: "input-9", type: "input", content: "dashboard" },
    { id: "info-10", type: "info", content: "Redirecting to dashboard..." },
  ]

  // Initialize the terminal sequence
  useEffect(() => {
    // Clear any existing state
    setDisplayedLines([])
    setCurrentTypingLine(null)
    setTypedContent("")
    setIsComplete(false)
    processedLinesRef.current.clear()

    // Start the sequence with a delay
    const timer = setTimeout(() => {
      processNextLine(0)
    }, 500)

    return () => clearTimeout(timer)
  }, [])

  // Function to process the next line in the sequence
  const processNextLine = (index: number) => {
    if (index >= terminalScript.length) {
      setIsComplete(true)
      return
    }

    const line = terminalScript[index]

    // Skip if already processed
    if (processedLinesRef.current.has(line.id)) {
      processNextLine(index + 1)
      return
    }

    // Mark as processed
    processedLinesRef.current.add(line.id)

    if (line.type === "input") {
      // For input lines, simulate typing
      setCurrentTypingLine(line)
      setTypedContent("")

      let charIndex = 0
      const typeNextChar = () => {
        if (charIndex < line.content.length) {
          setTypedContent(line.content.substring(0, charIndex + 1))
          charIndex++
          setTimeout(typeNextChar, 50 + Math.random() * 30) // Randomize typing speed slightly
        } else {
          // Typing complete, add to displayed lines
          setTimeout(() => {
            setDisplayedLines((prev) => {
              // Check if line already exists to prevent duplicates
              if (prev.some((l) => l.id === line.id)) return prev
              return [...prev, line]
            })
            setCurrentTypingLine(null)

            // Process next line after a delay
            setTimeout(() => {
              processNextLine(index + 1)
            }, 500)
          }, 300)
        }
      }

      // Start typing after a short delay
      setTimeout(typeNextChar, 300)
    } else {
      // For non-input lines, just display them after a delay
      setTimeout(() => {
        setDisplayedLines((prev) => {
          // Check if line already exists to prevent duplicates
          if (prev.some((l) => l.id === line.id)) return prev
          return [...prev, line]
        })

        // Process next line
        setTimeout(
          () => {
            processNextLine(index + 1)
          },
          line.type === "info" ? 800 : 1200,
        ) // Longer delay for non-info lines
      }, 800)
    }
  }

  // Auto-scroll to bottom
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight
    }
  }, [displayedLines, typedContent])

  return (
    <div className="relative">
      <div className="absolute -inset-0.5 bg-gradient-to-r from-teal-500 to-blue-500 rounded-xl blur opacity-30"></div>
      <div className="relative bg-black border border-teal-500/30 rounded-xl overflow-hidden">
        <div className="flex items-center justify-between px-4 py-2 border-b border-teal-500/30 bg-black/80">
          <div className="flex items-center gap-2">
            <Terminal className="h-4 w-4 text-teal-500" />
            <span className="text-sm font-medium text-teal-500">V4Forge Terminal</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="h-2.5 w-2.5 rounded-full bg-red-500/70"></div>
            <div className="h-2.5 w-2.5 rounded-full bg-yellow-500/70"></div>
            <div className="h-2.5 w-2.5 rounded-full bg-green-500/70"></div>
          </div>
        </div>

        <div
          ref={terminalRef}
          className="font-mono text-sm p-4 h-[350px] overflow-auto bg-black text-teal-500 scrollbar-thin scrollbar-thumb-teal-500/20 scrollbar-track-transparent"
        >
          {/* Displayed completed lines */}
          {displayedLines.map((line) => (
            <div key={line.id} className="mb-2">
              {line.type === "input" ? (
                <div className="flex items-center">
                  <span className="text-blue-500 mr-2">$</span>
                  <span className="text-white">{line.content}</span>
                </div>
              ) : line.type === "output" ? (
                <div className="text-yellow-400">{line.content}</div>
              ) : line.type === "success" ? (
                <div className="flex items-start">
                  <CheckCircle className="h-4 w-4 text-green-500 mr-2 mt-0.5" />
                  <span className="text-green-500">{line.content}</span>
                </div>
              ) : line.type === "error" ? (
                <div className="flex items-start">
                  <AlertCircle className="h-4 w-4 text-red-500 mr-2 mt-0.5" />
                  <span className="text-red-500">{line.content}</span>
                </div>
              ) : (
                <div className="text-teal-500">{line.content}</div>
              )}
            </div>
          ))}

          {/* Currently typing line */}
          {currentTypingLine && (
            <div className="flex items-center mb-2">
              <span className="text-blue-500 mr-2">$</span>
              <span className="text-white">{typedContent}</span>
              <span className="inline-block h-4 w-2 bg-blue-500 ml-0.5 animate-pulse"></span>
            </div>
          )}

          {/* Cursor at the end when finished */}
          {isComplete && !currentTypingLine && (
            <div className="flex items-center">
              <span className="text-blue-500 mr-2">$</span>
              <span className="inline-block h-4 w-2 bg-teal-500 animate-pulse"></span>
            </div>
          )}
        </div>

        <div className="px-4 py-3 border-t border-teal-500/30 bg-black/80">
          <Link to="/create">
            <Button className="w-full bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600">
              <Code className="h-4 w-4 mr-2" />
              Launch Your Token
              <ArrowRight className="h-4 w-4 ml-2" />
            </Button>
          </Link>
        </div>
      </div>
    </div>
  )
}
