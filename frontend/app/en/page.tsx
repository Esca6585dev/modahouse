import TopicPage, { topicMetadata } from "@/components/TopicPage";

type Props = { searchParams: Promise<{ page?: string }> };

export const generateMetadata = ({ searchParams }: Props) => topicMetadata("en", "fasonlar", searchParams);

export default function Page({ searchParams }: Props) {
  return <TopicPage lang="en" slug="fasonlar" search={searchParams} />;
}
