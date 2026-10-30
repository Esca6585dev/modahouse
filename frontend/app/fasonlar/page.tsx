import { redirect } from "next/navigation";
import TopicPage, { topicMetadata } from "@/components/TopicPage";
import { TOPICS, topicPath } from "@/lib/topics";

type Props = { searchParams: Promise<{ c?: string; page?: string }> };

export const generateMetadata = ({ searchParams }: Props) => topicMetadata("tk", "fasonlar", searchParams);

export default async function FasonlarPage({ searchParams }: Props) {
  // Old /fasonlar?c=<category> links go to the topic page of that category.
  const c = (await searchParams).c;
  const t = c && TOPICS.find((x) => x.category === c);
  if (t) redirect(topicPath("tk", t.slug));
  return <TopicPage lang="tk" slug="fasonlar" search={searchParams} />;
}
