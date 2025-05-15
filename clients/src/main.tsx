import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { WagmiConfigProvider } from './providers/Wagmi.js'
import "@rainbow-me/rainbowkit/styles.css";
import { BrowserRouter } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <WagmiConfigProvider>
      <BrowserRouter>
        <App />
        <Toaster
          // position="bottom-right"
          toastOptions={{
            className: "backdrop-blur-md bg-background/80 border border-border/50 shadow-xl",
            duration: 2000,
          }}
        />
      </BrowserRouter>
    </WagmiConfigProvider>
  </StrictMode>,
)
