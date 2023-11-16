import { LucideProps, User } from 'lucide-react'
import { Icon } from '@iconify/react';
export const Icons = {
  user: User,
  logo: (props: LucideProps) => (
    <svg xmlns="http://www.w3.org/2000/svg" {...props} width="24" height="24" viewBox="0 0 24 24" fill="white" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="lucide lucide-book-plus"><path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/><path d="M9 10h6"/><path d="M12 7v6"/></svg>
  ),
  // logo: () => (
  //   <Icon icon="la:tooth" className='h-14 w-12' />
  // )
}
