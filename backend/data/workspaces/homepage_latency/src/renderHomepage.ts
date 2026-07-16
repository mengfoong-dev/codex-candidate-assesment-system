interface HomepageParts {
  profile: unknown;
  recommendations: unknown;
  notices: unknown;
}

export function renderHomepage(parts: HomepageParts) {
  return {
    profile: parts.profile,
    recommendations: parts.recommendations,
    notices: parts.notices,
  };
}
