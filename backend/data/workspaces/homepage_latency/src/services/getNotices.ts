export async function getNotices(userId: string) {
  const response = await fetch(`/internal/notices?userId=${userId}`);
  return response.json();
}
