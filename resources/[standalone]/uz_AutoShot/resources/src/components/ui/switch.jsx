"use client"

import * as React from "react"
import * as SwitchPrimitives from "@radix-ui/react-switch"

import { cn } from "@/lib/utils"

const sizeMap = {
  default: {
    root:  "h-5 w-9",
    thumb: "h-4 w-4 data-[state=checked]:translate-x-[18px] data-[state=unchecked]:translate-x-0.5",
  },
  sm: {
    root:  "h-[10px] w-[18px]",
    thumb: "h-[8px] w-[8px] data-[state=checked]:translate-x-[9px] data-[state=unchecked]:translate-x-[1px]",
  },
}

const Switch = React.forwardRef(({ className, size = "default", ...props }, ref) => {
  const s = sizeMap[size] ?? sizeMap.default
  return (
    <SwitchPrimitives.Root
      className={cn(
        "peer inline-flex shrink-0 cursor-pointer items-center rounded-full transition-colors",
        "border border-zinc-700/60",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background",
        "disabled:cursor-not-allowed disabled:opacity-50",
        "data-[state=checked]:bg-[#FAFAFA] data-[state=unchecked]:bg-[#27272A]",
        s.root,
        className
      )}
      {...props}
      ref={ref}
    >
      <SwitchPrimitives.Thumb
        className={cn(
          "pointer-events-none block rounded-full bg-[#09090B] shadow-lg ring-0 transition-transform",
          s.thumb
        )}
      />
    </SwitchPrimitives.Root>
  )
})
Switch.displayName = SwitchPrimitives.Root.displayName

export { Switch }
