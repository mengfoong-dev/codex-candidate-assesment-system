export async function getRecommendations(userId: string) {
  const response = await fetch(`/internal/recommendations?userId=${userId}`);
  return response.json();
}
