const Page = async () => {
  return (
    <div className="flex-1 justify-between flex flex-col h-[calc(100vh-3.5rem)]">
      <div className="mx-auto w-full max-w-8xl grow lg:flex lg:px-1 xl:px-2">
        {/* TODO: create years component */}
        <div className="bg-red-300">hello</div>
      </div>
      <div className="bg-red-400">world</div>
    </div>
  );
};

export default Page;
