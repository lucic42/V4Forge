import { Link } from "react-router-dom"
import { Code, Github } from "lucide-react"

export const Footer = () => {
  return (
    <footer className="border-t border-teal-500/10 py-6 backdrop-blur-sm bg-background/40">
      <div className="container mx-auto px-4">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="relative h-8 w-8 overflow-hidden rounded-md bg-background border border-teal-500/30">
              <div className="absolute inset-0 flex items-center justify-center text-teal-500 font-bold text-lg">
                <Code size={18} className="text-teal-500" />
              </div>
            </div>
            <span className="font-bold">
              <span className="text-teal-500">V4</span>Forge
            </span>
          </div>

          <p className="text-sm text-muted-foreground">
            &copy; {new Date().getFullYear()} V4Forge. All rights reserved.
          </p>

          <Link
            to="https://github.com/hola-official/V4Forge"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-sm text-muted-foreground hover:text-teal-500 transition-colors"
          >
            <Github size={16} />
            GitHub
          </Link>
        </div>
      </div>
    </footer>
  )
}
