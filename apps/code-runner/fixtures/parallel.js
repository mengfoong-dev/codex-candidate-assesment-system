await requireAuthenticatedUser(userId);
const [details, recommendations, comments] = await Promise.all([
  getVideoDetails(videoId),
  getRecommendations(videoId),
  getComments(videoId),
]);
return renderWatchPage({ details, recommendations, comments });
