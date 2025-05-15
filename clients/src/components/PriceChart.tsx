"use client"

import { useRef, useEffect } from "react"
import { Line } from "react-chartjs-2"
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  type ChartData,
  type ChartOptions,
} from "chart.js"
import { motion } from "framer-motion"
import { useTheme } from "./theme-provider"

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend)

interface PriceChartProps {
  type: "dutch" | "exponential"
  startPrice: number
  endPrice: number
  showAfterLaunch?: boolean
}

const PriceChart = ({ type, startPrice, showAfterLaunch = false }: PriceChartProps) => {
  const chartRef = useRef<any>(null)
  const { theme } = useTheme()

  // Generate data points for the chart
  const generateChartData = (): ChartData<"line"> => {
    const labels = Array.from({ length: 10 }, (_, i) => `Day ${i + 1}`)

    // Generate price points based on the auction type
    const pricePoints = labels.map((_, i) => {
      const progress = i / 9 // 0 to 1

      if (type === "dutch") {
        // Dutch auction: price decreases over time
        return startPrice * (1 - progress * 0.7)
      } else {
        // Exponential: price increases as more tokens are sold
        return startPrice * Math.exp(progress * 2.3) // 2.3 is roughly ln(10)
      }
    })

    // Add post-launch data if requested
    const datasets = [
      {
        label: `${type === "dutch" ? "Dutch Auction" : "Exponential Launch"} Price`,
        data: pricePoints,
        borderColor: type === "dutch" ? "rgb(20, 184, 166)" : "rgb(99, 102, 241)",
        backgroundColor: type === "dutch" ? "rgba(20, 184, 166, 0.5)" : "rgba(99, 102, 241, 0.5)",
        tension: 0.4,
        borderWidth: 3,
        pointRadius: 4,
        pointHoverRadius: 6,
      },
    ]

    if (showAfterLaunch) {
      // Generate some random post-launch price movement
      const postLaunchLabels = Array.from({ length: 5 }, (_, i) => `Day ${i + 11}`)
      const allLabels = [...labels, ...postLaunchLabels]

      const lastPrice = pricePoints[pricePoints.length - 1]
      const volatility = 0.1 // 10% price movement

      const postLaunchPrices = postLaunchLabels.map((_) => {
        const randomFactor = 1 + (Math.random() * volatility * 2 - volatility)
        return lastPrice * randomFactor
      })

      const allPrices = [...pricePoints, ...postLaunchPrices]

      return {
        labels: allLabels,
        datasets: [
          {
            label: "Token Price",
            data: allPrices,
            borderColor: "rgb(20, 184, 166)",
            backgroundColor: "rgba(20, 184, 166, 0.5)",
            tension: 0.4,
            borderWidth: 3,
            pointRadius: 4,
            pointHoverRadius: 6,
          },
        ],
      }
    }

    return {
      labels,
      datasets,
    }
  }

  const options: ChartOptions<"line"> = {
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      y: {
        beginAtZero: false,
        ticks: {
          callback: (value) => "$" + value,
          color: theme === "dark" ? "rgba(255, 255, 255, 0.6)" : "rgba(0, 0, 0, 0.6)",
        },
        grid: {
          color: theme === "dark" ? "rgba(255, 255, 255, 0.1)" : "rgba(0, 0, 0, 0.1)",
        },
      },
      x: {
        ticks: {
          color: theme === "dark" ? "rgba(255, 255, 255, 0.6)" : "rgba(0, 0, 0, 0.6)",
        },
        grid: {
          color: theme === "dark" ? "rgba(255, 255, 255, 0.1)" : "rgba(0, 0, 0, 0.1)",
        },
      },
    },
    plugins: {
      legend: {
        position: "top" as const,
        labels: {
          color: theme === "dark" ? "rgba(255, 255, 255, 0.8)" : "rgba(0, 0, 0, 0.8)",
          font: {
            weight: "bold",
          },
        },
      },
      tooltip: {
        callbacks: {
          label: (context) => `Price: $${context.parsed.y.toFixed(4)}`,
        },
        backgroundColor: theme === "dark" ? "rgba(0, 0, 0, 0.8)" : "rgba(255, 255, 255, 0.8)",
        titleColor: theme === "dark" ? "rgba(255, 255, 255, 0.8)" : "rgba(0, 0, 0, 0.8)",
        bodyColor: theme === "dark" ? "rgba(255, 255, 255, 0.8)" : "rgba(0, 0, 0, 0.8)",
        borderColor: theme === "dark" ? "rgba(255, 255, 255, 0.2)" : "rgba(0, 0, 0, 0.2)",
        borderWidth: 1,
      },
    },
    animation: {
      duration: 2000,
    },
  }

  const data = generateChartData()

  // Add gradient background
  useEffect(() => {
    const chart = chartRef.current

    if (chart) {
      const ctx = chart.ctx
      const gradient = ctx.createLinearGradient(0, 0, 0, chart.height)

      if (type === "dutch") {
        gradient.addColorStop(0, "rgba(20, 184, 166, 0.3)")
        gradient.addColorStop(1, "rgba(20, 184, 166, 0)")
      } else if (type === "exponential") {
        gradient.addColorStop(0, "rgba(99, 102, 241, 0.3)")
        gradient.addColorStop(1, "rgba(99, 102, 241, 0)")
      } else {
        gradient.addColorStop(0, "rgba(20, 184, 166, 0.3)")
        gradient.addColorStop(1, "rgba(20, 184, 166, 0)")
      }

      if (chart.data.datasets[0]) {
        chart.data.datasets[0].backgroundColor = gradient
        chart.update()
      }
    }
  }, [chartRef, type, theme])

  return (
    <motion.div
      className="w-full h-full"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: 0.2 }}
    >
      <Line ref={chartRef} options={options} data={data} />
    </motion.div>
  )
}

export default PriceChart
