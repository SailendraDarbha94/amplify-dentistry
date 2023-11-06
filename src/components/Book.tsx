"use client";

import { format } from "date-fns";
import { Loader2, MessageSquare, Plus, Trash } from "lucide-react"
import Link from "next/link"
import { Button } from "./ui/button"
import { useState } from "react"
import { trpc } from "@/app/_trpc/client"



const Book = ( file:any ) => {
    const utils = trpc.useContext();
    const { mutate: deleteFile } = trpc.deleteFile.useMutation({
        onSuccess: () => {
          utils.getUserFiles.invalidate();
        },
        onMutate({ id }) {
          setCurrentlyDeletingFile(id);
        },
        onSettled() {
          setCurrentlyDeletingFile(null);
        },
      });
    const [currentlyDeletingFile, setCurrentlyDeletingFile] = useState<string | null>(null);
    return (
        <li
        key={file.id}
        className="col-span-1 divide-y divide-gray-200 rounded-lg bg-white shadow transition hover:shadow-lg"
      >
        <Link
          href={`/dashboard/${file.id}`}
          className="flex flex-col gap-2"
        >
          <div className="pt-6 px-6 flex w-full items-center justify-between space-x-6">
            <div className="h-10 w-10 flex-shrink-0 rounded-full bg-gradient-to-r from-cyan-500 to-blue-500" />
            <div className="flex-1 truncate">
              <div className="flex items-center space-x-3">
                <h3 className="truncate text-lg font-medium text-zinc-900">
                  {file.name}
                </h3>
              </div>
            </div>
          </div>
        </Link>

        <div className="px-6 mt-4 grid grid-cols-3 place-items-center py-2 gap-6 text-xs text-zinc-500">
          <div className="flex items-center gap-2">
            <Plus className="h-4 w-4" />
            {file.createdAt}
          </div>

          <div className="flex items-center gap-2">
            <MessageSquare className="h-4 w-4" />
            mocked
          </div>

          <Button
            onClick={() => deleteFile({ id: file.id })}
            size="sm"
            className="w-full"
            variant="destructive"
          >
            {currentlyDeletingFile === file.id ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Trash className="h-4 w-4" />
            )}
          </Button>
        </div>
      </li>
    )
}

export default Book