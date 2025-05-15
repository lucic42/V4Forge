import { useState, useEffect } from "react"
import { useParams } from "react-router-dom"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ExternalLink, TrendingUp, Clock, ArrowRight } from "lucide-react"
import { mockLaunches } from "@/lib/mock-data"
import PriceChart from "@/components/PriceChart"

const TokenDetails = () => {
  const { id } = useParams()
  const [token, setToken] = useState<any>(null)

  useEffect(() => {
    // Find the token with the matching id
    const foundToken = mockLaunches.find((t) => t.id === id)
    if (foundToken) {
      setToken(foundToken)
    }
  }, [id])

  if (!token) {
    return <div className="flex justify-center items-center h-64">Loading...</div>
  }

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <img src={token.logoUrl || "/placeholder.svg"} alt={token.name} className="w-10 h-10 rounded-full" />
          <div>
            <h1 className="text-2xl font-bold">{token.name}</h1>
            <p className="text-muted-foreground">{token.ticker}</p>
          </div>
        </div>
        <div className="flex space-x-2">
          <a href={token.website} target="_blank" rel="noopener noreferrer">
            <Button variant="outline" size="sm" className="flex items-center gap-1">
              Website <ExternalLink className="h-3 w-3" />
            </Button>
          </a>
          <Button variant="outline" size="sm" className="flex items-center gap-1">
            View on Explorer <ExternalLink className="h-3 w-3" />
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>Token Overview</CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Current Price</p>
                <p className="font-medium text-xl">${token.currentPrice.toFixed(4)}</p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Market Cap</p>
                <p className="font-medium text-xl">${(token.currentPrice * token.totalSupply).toLocaleString()}</p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Total Supply</p>
                <p className="font-medium">
                  {token.totalSupply.toLocaleString()} {token.ticker}
                </p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Launch Type</p>
                <p className="font-medium flex items-center">
                  {token.type === "dutch" ? (
                    <>
                      Dutch Auction <TrendingUp className="ml-1 h-3 w-3" />
                    </>
                  ) : (
                    <>
                      Exponential <Clock className="ml-1 h-3 w-3" />
                    </>
                  )}
                </p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Launch Date</p>
                <p className="font-medium">{new Date(token.startTime).toLocaleDateString()}</p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Launch Ended</p>
                <p className="font-medium">{new Date(token.endTime).toLocaleDateString()}</p>
              </div>
            </div>

            <div className="pt-4">
              <h3 className="font-medium mb-3">Price History</h3>
              <div className="h-64">
                <PriceChart
                  type={token.type}
                  startPrice={token.initialPrice}
                  endPrice={token.currentPrice}
                  showAfterLaunch={true}
                />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Token Information</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <h3 className="font-medium mb-2">Description</h3>
              <p className="text-sm text-muted-foreground">{token.description}</p>
            </div>

            <div>
              <h3 className="font-medium mb-2">Social Links</h3>
              <div className="space-y-2">
                {token.socialLinks.map((link: any) => (
                  <a
                    key={link.name}
                    href={link.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center justify-between text-sm hover:underline"
                  >
                    <span>{link.name}</span>
                    <ExternalLink className="h-3 w-3" />
                  </a>
                ))}
              </div>
            </div>

            <div>
              <h3 className="font-medium mb-2">Contract Address</h3>
              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground truncate w-36">{token.contractAddress}</span>
                <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                  <ExternalLink className="h-3 w-3" />
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>About {token.name}</CardTitle>
        </CardHeader>
        <CardContent>
          <p>{token.longDescription}</p>

          <div className="mt-6">
            <Button variant="outline" className="flex items-center gap-2">
              Trade {token.ticker} <ArrowRight className="h-4 w-4" />
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default TokenDetails
