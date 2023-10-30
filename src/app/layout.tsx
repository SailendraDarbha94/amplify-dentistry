// import type { Metadata } from 'next'
// import { Inter } from 'next/font/google'
// import './globals.css'

// const inter = Inter({ subsets: ['latin'] })

// export const metadata: Metadata = {
//   title: 'Amplify Dentistry',
//   description: 'Created for dental students by dental developer',
// }

// export default function RootLayout({
//   children,
// }: {
//   children: React.ReactNode
// }) {
//   return (
//     <html lang="en">
//       <body className={inter.className}>{children}</body>
//     </html>
//   )
// }

import type { Metadata } from 'next'
import Navbar from '@/components/Navbar'
// import Providers from '@/components/Providers'
import { cn, constructMetadata } from '@/lib/utils'
import { Inter } from 'next/font/google'
import './globals.css'

// import 'react-loading-skeleton/dist/skeleton.css'
// import 'simplebar-react/dist/simplebar.min.css'

// import { Toaster } from '@/components/ui/toaster'

const inter = Inter({ subsets: ['latin'] })

//export const metadata = constructMetadata()
export const metadata: Metadata = {
  title: 'Amplify Dentistry',
  description: 'Created for dental students by dental developer',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang='en' className='light'>
      {/* <Providers> */}
        <body
          className={cn(
            'min-h-screen font-sans antialiased grainy',
            inter.className
          )}>
          {/* <Toaster /> */}
          <Navbar />
          {children}
        </body>
      {/* </Providers> */}
    </html>
  )
}
