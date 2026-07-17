await requireAuthenticatedUser(userId);
const details = await getVideoDetails(videoId);
const recommendations = await getRecommendations(videoId);
const comments = await getComments(videoId);
return renderWatchPage({ details, recommendations, comments });
