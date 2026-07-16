import { requireAuthenticatedUser } from "./services/requireAuthenticatedUser";
import { getProfile } from "./services/getProfile";
import { getRecommendations } from "./services/getRecommendations";
import { getNotices } from "./services/getNotices";
import { renderHomepage } from "./renderHomepage";

export async function renderHomepageForUser(userId: string) {
  await requireAuthenticatedUser(userId);
  const profile = await getProfile(userId);
  const recommendations = await getRecommendations(userId);
  const notices = await getNotices(userId);
  return renderHomepage({ profile, recommendations, notices });
}
