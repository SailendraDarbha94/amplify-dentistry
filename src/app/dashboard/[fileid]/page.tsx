import ChatWrapper from '@/components/chat/ChatWrapper'
import PdfRenderer from '@/components/PdfRenderer'
import { Loader2, MessageSquare, Plus, Trash, BookOpen } from "lucide-react";
import { db } from '@/db'
import { getUserSubscriptionPlan } from '@/lib/stripe'
import { getKindeServerSession } from '@kinde-oss/kinde-auth-nextjs/server'
import { notFound, redirect } from 'next/navigation'

interface PageProps {
  params: {
    fileid: string
  }
}

const Page = async ({ params }: PageProps) => {
  const { fileid } = params

  const { getUser } = getKindeServerSession()
  const user = getUser()

  if (!user || !user.id)
    redirect(`/auth-callback?origin=dashboard/${fileid}`)

  const file = await db.file.findFirst({
    where: {
      id: fileid,
      userId: user.id,
    },
  })

  if (!file) notFound()

  //const plan = await getUserSubscriptionPlan()

  return (
    <div className='flex-1 justify-between flex flex-col h-[calc(100vh-3.5rem)]'>
      <div className='mx-auto w-full max-w-8xl grow lg:flex xl:px-2'>
        {/* Left sidebar & main wrapper */}
        <div className='flex-1 xl:flex'>
          <div className='px-4 py-6 sm:px-6 lg:pl-8 xl:flex-1 xl:pl-6 hidden md:block'>
            {/* Main area */}
            {/* <PdfRenderer url={file.url} /> */}
            <BookOpen color='royalblue' height={400} width={300} className='mx-auto' />
            <h3 className='text-center border-b-2 border-blue-600 text-3xl p-2'>
              {file.name.split('.')[0]}
            </h3>
            <p className='text-center text-lg'>
              Ask any doubts you have regarding the contents of this book
            </p>
          </div>
        </div>

        <div className='shrink-0 flex-[0.75] border-t border-gray-200 lg:w-96 lg:border-l lg:border-t-0'>
          <ChatWrapper isSubscribed={true} fileId={file.id} />
        </div>
      </div>
    </div>
  )
}

export default Page
