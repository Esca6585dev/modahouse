import TopicPage, { topicMetadata } from "@/components/TopicPage";

type Props = { params: Promise<{ topic: string }>; searchParams: Promise<{ page?: string }> };

export async function generateMetadata({ params, searchParams }: Props) {
  return topicMetadata("tk", (await params).topic, searchParams);
}

export default async function Page({ params, searchParams }: Props) {
  return <TopicPage lang="tk" slug={(await params).topic} search={searchParams} />;
}
