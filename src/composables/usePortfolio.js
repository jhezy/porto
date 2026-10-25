import { ref } from "vue";
import { supabase, isSupabaseConfigured } from "../lib/supabase";

// ========================================
// STATE: PROJECTS
// ========================================
const projects = ref([]);
const projectsLoading = ref(false);
const projectsError = ref("");

// ========================================
// STATE: SITE PROFILE
// ========================================
const siteProfile = ref(null);
const profileLoading = ref(false);
const profileError = ref("");

// ========================================
// STATE: CERTIFICATES
// ========================================
const certificates = ref([]);
const certificatesLoading = ref(false);
const certificatesError = ref("");

export function usePortfolio() {
  // ========================================
  // FETCH PUBLISHED PROJECTS
  // ========================================
  async function fetchPublishedProjects({ force = false } = {}) {
    if (!isSupabaseConfigured || !supabase) {
      projectsError.value =
        "Supabase belum dikonfigurasi. Periksa file environment.";
      projects.value = [];
      return [];
    }

    if (projects.value.length && !force) {
      return projects.value;
    }

    projectsLoading.value = true;
    projectsError.value = "";

    try {
      const { data, error } = await supabase
        .from("projects")
        .select(
          `
          id,
          title,
          slug,
          summary,
          description,
          thumbnail_url,
          live_url,
          repository_url,
          featured,
          sort_order,
          published_at,
          project_categories(name, slug)
        `,
        )
        .eq("status", "published")
        .order("featured", { ascending: false })
        .order("sort_order", { ascending: true })
        .order("published_at", { ascending: false });

      if (error) throw error;

      projects.value = data ?? [];
      return projects.value;
    } catch (error) {
      projectsError.value = error.message || "Gagal mengambil data proyek.";
      projects.value = [];
      return [];
    } finally {
      projectsLoading.value = false;
    }
  }

  // ========================================
  // FETCH PROJECT DETAIL
  // ========================================
  async function fetchProjectBySlug(slug) {
    if (!isSupabaseConfigured || !supabase) {
      throw new Error("Supabase belum dikonfigurasi.");
    }

    const { data, error } = await supabase
      .from("projects")
      .select("*, project_categories(name, slug)")
      .eq("slug", slug)
      .eq("status", "published")
      .maybeSingle();

    if (error) throw error;

    return data;
  }

  // ========================================
  // FETCH SITE PROFILE
  // ========================================
  async function fetchSiteProfile({ force = false } = {}) {
    if (!isSupabaseConfigured || !supabase) {
      profileError.value =
        "Supabase belum dikonfigurasi. Periksa file environment.";
      siteProfile.value = null;
      return null;
    }

    if (siteProfile.value && !force) {
      return siteProfile.value;
    }

    profileLoading.value = true;
    profileError.value = "";

    try {
      const { data, error } = await supabase
        .from("site_profile")
        .select("*")
        .limit(1)
        .maybeSingle();

      if (error) throw error;

      if (!data) {
        throw new Error("Data profil belum tersedia di tabel site_profile.");
      }

      siteProfile.value = data;
      return siteProfile.value;
    } catch (error) {
      profileError.value = error.message || "Gagal mengambil data profil.";
      siteProfile.value = null;
      return null;
    } finally {
      profileLoading.value = false;
    }
  }

  // ========================================
  // FETCH VISIBLE CERTIFICATES
  // ========================================
  async function fetchCertificates({ force = false } = {}) {
    if (!isSupabaseConfigured || !supabase) {
      certificatesError.value = "Supabase belum dikonfigurasi.";
      certificates.value = [];
      return [];
    }

    if (certificates.value.length && !force) {
      return certificates.value;
    }

    certificatesLoading.value = true;
    certificatesError.value = "";

    try {
      const { data, error } = await supabase
        .from("certificates")
        .select(
          `
  id,
  title,
  issuer,
  credential_url,
  issued_at,
  image_url,
  file_url,
  sort_order,
  is_visible
`,
        )
        .eq("is_visible", true)
        .order("sort_order", { ascending: true })
        .order("issued_at", {
          ascending: false,
          nullsFirst: false,
        });

      if (error) throw error;

      certificates.value = data ?? [];
      return certificates.value;
    } catch (error) {
      console.error("Gagal mengambil sertifikat:", error);

      certificatesError.value =
        error.message || "Sertifikat belum dapat dimuat.";

      certificates.value = [];
      return [];
    } finally {
      certificatesLoading.value = false;
    }
  }

  // ========================================
  // RETURN PUBLIC STATE & FUNCTIONS
  // ========================================
  return {
    // Projects
    projects,
    projectsLoading,
    projectsError,
    fetchPublishedProjects,
    fetchProjectBySlug,

    // Profile
    siteProfile,
    profileLoading,
    profileError,
    fetchSiteProfile,

    // Certificates
    certificates,
    certificatesLoading,
    certificatesError,
    fetchCertificates,
  };
}
