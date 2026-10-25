<script setup>
import { computed, onMounted, onBeforeUnmount, ref } from "vue";
import { RouterLink } from "vue-router";
import { supabase } from "../lib/supabase";
import { usePortfolio } from "../composables/usePortfolio";

const {
  projects,
  projectsLoading,
  projectsError,
  fetchPublishedProjects,
  siteProfile,
  // profileLoading,
  profileError,
  fetchSiteProfile,
  // Certificates
  certificates,
  certificatesLoading,
  certificatesError,
  fetchCertificates,
} = usePortfolio();

onMounted(async () => {
  await Promise.all([
    fetchPublishedProjects(),
    fetchSiteProfile(),
    fetchCertificates(),
  ]);
});

function formatCertificateDate(date) {
  if (!date) return "";

  const parsedDate = new Date(`${date.slice(0, 10)}T00:00:00`);

  if (Number.isNaN(parsedDate.getTime())) return "";

  return parsedDate.toLocaleDateString("id-ID", {
    month: "long",
    year: "numeric",
  });
}

const profile = ref(null);
const profileLoading = ref(true);
const mobileMenuOpen = ref(false);
const currentYear = new Date().getFullYear();

const displayName = computed(
  () => profile.value?.display_name || "Creative Developer",
);

const firstName = computed(() => displayName.value.split(" ")[0]);

const headline = computed(
  () => profile.value?.headline || "Web Developer & Digital Creator",
);

const bio = computed(
  () =>
    profile.value?.bio ||
    "Saya membangun pengalaman digital yang menggabungkan teknologi, desain, dan pemecahan masalah.",
);

const location = computed(() => profile.value?.location || "Indonesia");

const email = computed(() => profile.value?.email || "");

const avatar = computed(() => profile.value?.avatar_url || "");

const seoTitle = computed(
  () => profile.value?.seo_title || `${displayName.value} — Portfolio`,
);

const seoDescription = computed(
  () =>
    profile.value?.seo_description ||
    "Portfolio personal yang menampilkan proyek, keahlian, dan perjalanan di dunia teknologi.",
);

const searchQuery = ref("");
const selectedCategory = ref("all");

// Kategori unik dari proyek yang sudah diambil dari Supabase.
const projectCategories = computed(() => {
  const categories = projects.value
    .map((project) => project.project_categories)
    .flat()
    .filter((category) => category?.name && category?.slug);

  return [
    { name: "Semua", slug: "all" },
    ...Array.from(
      new Map(
        categories.map((category) => [
          category.slug,
          { name: category.name, slug: category.slug },
        ]),
      ).values(),
    ).sort((a, b) => a.name.localeCompare(b.name)),
  ];
});

// Pencarian judul, ringkasan, deskripsi, dan kategori.
const filteredProjects = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase();

  return projects.value.filter((project) => {
    const category = project.project_categories;

    const categoryList = Array.isArray(category)
      ? category
      : category
        ? [category]
        : [];

    const matchesCategory =
      selectedCategory.value === "all" ||
      categoryList.some((item) => item?.slug === selectedCategory.value);

    const searchableText = [
      project.title,
      project.summary,
      project.description,
      ...categoryList.map((item) => item?.name),
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();

    const matchesSearch = searchableText.includes(keyword);

    return matchesCategory && matchesSearch;
  });
});
const experiences = ref([]);
const experiencesLoading = ref(false);
const experiencesError = ref("");
async function fetchExperiences() {
  experiencesLoading.value = true;
  experiencesError.value = "";

  try {
    const { data, error } = await supabase
      .from("experiences")
      .select(
        `
        id,
        organization,
        role,
        employment_type,
        location,
        description,
        start_date,
        end_date,
        is_current,
        sort_order
      `,
      )
      .eq("is_visible", true)
      .eq("is_published", true)
      .order("sort_order", { ascending: true })
      .order("start_date", { ascending: false });

    if (error) throw error;

    experiences.value = data ?? [];
  } catch (error) {
    console.error("Gagal mengambil pengalaman:", error);
    experiencesError.value = "Pengalaman belum dapat dimuat.";
  } finally {
    experiencesLoading.value = false;
  }
}

function formatExperienceDate(date) {
  if (!date) return "";

  return new Date(`${date.slice(0, 10)}T00:00:00`).toLocaleDateString("id-ID", {
    month: "short",
    year: "numeric",
  });
}

function experiencePeriod(item) {
  const start = formatExperienceDate(item.start_date);
  const end = item.is_current
    ? "Sekarang"
    : formatExperienceDate(item.end_date);

  if (start && end) return `${start} — ${end}`;
  return start || end || "Periode tidak dicantumkan";
}

async function loadProfile() {
  profileLoading.value = true;

  try {
    const { data, error } = await supabase
      .from("site_profile")
      .select(
        "display_name, headline, bio, avatar_url, location, email, seo_title, seo_description",
      )
      .limit(1)
      .maybeSingle();

    if (error) throw error;

    profile.value = data;
  } catch (error) {
    console.error("Gagal memuat profil:", error.message);
  } finally {
    profileLoading.value = false;
  }
}

function closeMobileMenu() {
  mobileMenuOpen.value = false;
}

function handleEscape(event) {
  if (event.key === "Escape") closeMobileMenu();
}

onMounted(async () => {
  document.addEventListener("keydown", handleEscape);

  await Promise.all([
    loadProfile(),
    fetchPublishedProjects(),
    fetchExperiences(),
    fetchCertificates(),
  ]);
});

onBeforeUnmount(() => {
  document.removeEventListener("keydown", handleEscape);
});

// SEO metadata dasar untuk halaman utama.
import { watch } from "vue";

watch(
  [seoTitle, seoDescription],
  ([title, description]) => {
    document.title = title;

    let meta = document.querySelector('meta[name="description"]');

    if (!meta) {
      meta = document.createElement("meta");
      meta.name = "description";
      document.head.appendChild(meta);
    }

    meta.content = description;
  },
  { immediate: true },
);
</script>

<template>
  <div class="portfolio-home">
    <!-- NAVBAR -->
    <header class="site-header">
      <nav class="site-container nav-inner">
        <RouterLink
          to="/"
          class="brand"
          @click="closeMobileMenu"
        >
          <span class="brand-symbol">J.</span>
          <span class="brand-name">
            {{ displayName }}
            <span class="brand-dot">.</span>
          </span>
        </RouterLink>

        <button
          class="mobile-toggle"
          type="button"
          aria-label="Buka navigasi"
          :aria-expanded="mobileMenuOpen"
          @click="mobileMenuOpen = !mobileMenuOpen"
        >
          <i :class="mobileMenuOpen ? 'bi bi-x-lg' : 'bi bi-list'"></i>
        </button>

        <div :class="['nav-links', { 'nav-links-open': mobileMenuOpen }]">
          <a
            href="#work"
            @click="closeMobileMenu"
            >Proyek</a
          >
          <a
            href="#about"
            @click="closeMobileMenu"
            >Tentang</a
          >
          <a
            href="#contact"
            @click="closeMobileMenu"
            >Kontak</a
          >
          <a
            href="#certificates"
            @click="closeMobileMenu"
          >
            Sertifikat
          </a>

          <RouterLink
            to="/admin/login"
            class="nav-admin"
            @click="closeMobileMenu"
          >
            <i class="bi bi-grid-1x2 me-2"></i>
            Dashboard
          </RouterLink>
        </div>
      </nav>
    </header>

    <main>
      <!-- HERO -->
      <section class="hero-section">
        <div class="hero-grid"></div>

        <div class="site-container hero-layout">
          <div class="hero-content">
            <div class="availability">
              <span class="availability-dot"></span>
              <span> {{ currentYear }}</span>
            </div>

            <!-- Nama dan headline -->

            <h1 class="hero-title mb-4">
              {{ siteProfile?.display_name || "Nama Anda" }}<br />
              <span class="text-accent">
                {{ siteProfile?.headline || "Web Developer" }}
              </span>
            </h1>

            <p class="hero-copy mb-4">
              <!-- {{
                siteProfile?.bio ||
                "Membangun pengalaman digital melalui teknologi dan kreativitas."
              }} -->
            </p>

            <!-- Tombol kontak -->
            <div class="d-flex flex-wrap gap-2">
              <a
                class="btn btn-accent"
                href="#work"
              >
                Jelajahi proyek
                <i class="bi bi-arrow-down-right ms-2"></i>
              </a>

              <a
                v-if="siteProfile?.email"
                class="btn btn-outline-soft"
                :href="`mailto:${siteProfile.email}`"
              >
                <i class="bi bi-envelope me-2"></i>
                Hubungi saya
              </a>
            </div>

            <div class="hero-meta">
              <div class="hero-meta-item">
                <i class="bi bi-code-slash"></i>
                <span>Web Development</span>
              </div>
              <span class="meta-divider"></span>
              <div class="hero-meta-item">
                <i class="bi bi-shield-check"></i>
                <span>Security-minded</span>
              </div>
              <span class="meta-divider"></span>
              <div class="hero-meta-item">
                <i class="bi bi-vector-pen"></i>
                <span>Design Thinking</span>
              </div>
            </div>
          </div>

          <div class="hero-visual">
            <div class="visual-glow"></div>

            <div class="visual-card">
              <div class="visual-card-top">
                <div class="window-dots">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
                <span class="visual-label">ABOUT.ME</span>
              </div>

              <div class="profile-art">
                <div class="profile-ring"></div>

                <img
                  v-if="avatar"
                  :src="avatar"
                  :alt="displayName"
                  class="profile-avatar"
                />

                <div
                  v-else
                  class="profile-avatar profile-avatar-fallback"
                >
                  <span>{{ firstName.charAt(0).toUpperCase() }}</span>
                </div>

                <span class="orbit orbit-one"></span>
                <span class="orbit orbit-two"></span>
                <span class="orbit orbit-three"></span>

                <div class="floating-chip chip-code">
                  <i class="bi bi-code-slash"></i>
                  <span>Clean code</span>
                </div>

                <div class="floating-chip chip-design">
                  <i class="bi bi-stars"></i>
                  <span>Creative mind</span>
                </div>
              </div>

              <div class="visual-card-bottom">
                <div>
                  <p class="visual-eyebrow">CURRENTLY EXPLORING</p>
                  <h2>{{ headline }}</h2>
                </div>
                <span class="visual-arrow">
                  <i class="bi bi-arrow-up-right"></i>
                </span>
              </div>
            </div>

            <div class="floating-index index-top">
              <span class="index-number">01</span>
              <span>DESIGN</span>
            </div>

            <div class="floating-index index-bottom">
              <span class="index-number">02</span>
              <span>DEVELOP</span>
            </div>
          </div>
        </div>

        <div class="hero-bottom site-container">
          <span>BASED IN {{ location.toUpperCase() }}</span>
          <a
            href="#work"
            class="scroll-indicator"
          >
            SCROLL TO EXPLORE
            <i class="bi bi-arrow-down"></i>
          </a>
        </div>
      </section>

      <!-- ABOUT -->
      <section
        id="about"
        class="section-block about-section"
      >
        <div class="site-container">
          <div class="about-panel">
            <div class="about-decoration">“</div>

            <div class="section-heading about-heading">
              <div>
                <p class="section-eyebrow">
                  <span>02</span> / A LITTLE ABOUT ME
                </p>

                <h2 class="section-title">
                  Bukan sekadar kode.
                  <span class="text-accent">Sebuah tujuan.</span>
                </h2>
              </div>
            </div>

            <div class="about-content">
              <div class="about-identity">
                <div class="about-avatar">
                  <img
                    v-if="avatar"
                    :src="avatar"
                    :alt="displayName"
                    loading="lazy"
                  />
                  <span v-else>
                    {{ firstName.charAt(0).toUpperCase() }}
                  </span>
                </div>

                <h3>{{ displayName }}</h3>
                <p>{{ headline }}</p>

                <div class="about-location">
                  <i class="bi bi-geo-alt"></i>
                  {{ location }}
                </div>
              </div>

              <div class="about-copy">
                <p>{{ bio }}</p>

                <p>
                  Saya tertarik membangun produk digital yang tidak hanya
                  terlihat baik, tetapi juga memiliki struktur yang kuat,
                  pengalaman pengguna yang nyaman, dan keamanan yang
                  diperhatikan sejak awal.
                </p>

                <div class="about-values">
                  <div class="value-item">
                    <span class="value-icon">
                      <i class="bi bi-braces"></i>
                    </span>
                    <div>
                      <h4>Development</h4>
                      <p>Membangun solusi yang fungsional dan terstruktur.</p>
                    </div>
                  </div>

                  <div class="value-item">
                    <span class="value-icon">
                      <i class="bi bi-fingerprint"></i>
                    </span>
                    <div>
                      <h4>Security mindset</h4>
                      <p>Memperhatikan keamanan dan keandalan sistem.</p>
                    </div>
                  </div>

                  <div class="value-item">
                    <span class="value-icon">
                      <i class="bi bi-lightbulb"></i>
                    </span>
                    <div>
                      <h4>Continuous learning</h4>
                      <p>Terus bereksperimen, belajar, dan berkembang.</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- EXPERIENCE -->
      <section
        id="experience"
        class="section-block experience-section"
      >
        <div class="site-container">
          <div class="experience-header">
            <div>
              <p class="section-eyebrow"><span>03</span> / MY JOURNEY</p>

              <h2 class="section-title">
                Pengalaman.
                <span class="text-accent">Proses bertumbuh.</span>
              </h2>

              <p class="experience-intro">
                Perjalanan profesional, tanggung jawab, dan pengalaman yang
                membentuk cara saya membangun solusi digital.
              </p>
            </div>

            <div class="experience-header-icon">
              <i class="bi bi-briefcase"></i>
            </div>
          </div>

          <!-- Loading -->
          <div
            v-if="experiencesLoading"
            class="experience-state"
          >
            <span
              class="spinner-border spinner-border-sm me-2"
              role="status"
              aria-hidden="true"
            ></span>
            Memuat pengalaman...
          </div>

          <!-- Error -->
          <div
            v-else-if="experiencesError"
            class="experience-state experience-error"
          >
            <i class="bi bi-exclamation-circle me-2"></i>
            {{ experiencesError }}
          </div>

          <!-- Empty -->
          <div
            v-else-if="experiences.length === 0"
            class="experience-empty"
          >
            <div class="experience-empty-icon">
              <i class="bi bi-journal-text"></i>
            </div>

            <h3>Perjalanan sedang dibangun</h3>
            <p>Pengalaman profesional akan ditampilkan di sini.</p>
          </div>

          <!-- Experience timeline -->

          <div
            v-else
            class="experience-timeline"
          >
            <article
              v-for="(item, index) in experiences"
              :key="item.id"
              class="experience-item"
            >
              <div class="experience-rail">
                <span class="experience-index">
                  {{ String(index + 1).padStart(2, "0") }}
                </span>
                <span class="experience-line"></span>
              </div>

              <div class="experience-card">
                <!-- Header -->
                <div class="experience-card-top">
                  <div class="experience-main">
                    <div class="experience-badges">
                      <span
                        v-if="item.is_current"
                        class="experience-current"
                      >
                        <span class="current-dot"></span>
                        Saat ini
                      </span>

                      <span
                        v-if="item.employment_type"
                        class="experience-type"
                      >
                        {{ item.employment_type }}
                      </span>
                    </div>

                    <!-- Role, Organization, Location dalam satu baris -->
                    <div class="experience-info-row">
                      <h3 class="experience-role">
                        {{ item.role }}
                      </h3>

                      <span class="experience-info-separator"></span>

                      <span class="experience-organization">
                        <i class="bi bi-building"></i>
                        {{ item.organization }}
                      </span>

                      <span
                        v-if="item.location"
                        class="experience-info-separator"
                      ></span>

                      <span
                        v-if="item.location"
                        class="experience-location"
                      >
                        <i class="bi bi-geo-alt"></i>
                        {{ item.location }}
                      </span>
                    </div>
                  </div>

                  <!-- Periode -->
                  <div class="experience-period">
                    <i class="bi bi-calendar3"></i>
                    <span>{{ experiencePeriod(item) }}</span>
                  </div>
                </div>

                <!-- Description -->
                <p
                  v-if="item.description"
                  class="experience-description"
                >
                  {{ item.description }}
                </p>
              </div>
            </article>
          </div>
        </div>
      </section>

      <!-- PROJECTS -->
      <section
        id="work"
        class="section-block work-section"
      >
        <div class="site-container">
          <div class="section-heading">
            <div>
              <p class="section-eyebrow"><span>01</span> / SELECTED WORK</p>
              <h2 class="section-title">
                Karya yang
                <span class="text-accent">berbicara.</span>
              </h2>
            </div>

            <p class="section-side-note">
              Beberapa proyek yang merepresentasikan ide, proses, dan solusi
              yang saya bangun.
            </p>
          </div>

          <div
            v-if="projectsLoading"
            class="state-panel"
          >
            <div
              class="spinner-border text-accent"
              role="status"
            ></div>
            <p>Menyiapkan karya terbaik...</p>
          </div>

          <div
            v-else-if="projectsError"
            class="state-panel state-error"
          >
            <i class="bi bi-exclamation-circle"></i>
            <p>{{ projectsError }}</p>
          </div>

          <div
            v-else-if="projects.length === 0"
            class="empty-projects"
          >
            <div class="empty-icon">
              <i class="bi bi-box"></i>
            </div>
            <p class="section-eyebrow">THE STORY STARTS HERE</p>
            <h3>Ruang untuk karya berikutnya.</h3>
            <p>
              Proyek yang dipublikasikan akan muncul di sini secara otomatis.
            </p>
            <RouterLink
              to="/admin/login"
              class="btn-secondary-custom"
            >
              Kelola proyek <i class="bi bi-arrow-up-right ms-2"></i>
            </RouterLink>
          </div>

          <div
            v-else
            class="project-grid"
          >
            <article
              v-for="project in projects"
              :key="project.id"
              class="project-card"
            >
              <!-- Preview gambar -->
              <div class="project-image-wrap">
                <img
                  v-if="project.thumbnail_url"
                  :src="project.thumbnail_url"
                  :alt="project.title"
                  class="project-image"
                  loading="lazy"
                />

                <div
                  v-else
                  class="project-image-placeholder"
                >
                  <i class="bi bi-window-stack"></i>
                </div>

                <!-- <span class="project-category-badge">
                  {{ project.project_categories?.name || "PROJECT" }}
                </span> -->

                <RouterLink
                  :to="{
                    name: 'project-detail',
                    params: { slug: project.slug },
                  }"
                  class="project-image-action"
                  :aria-label="`Lihat detail ${project.title}`"
                >
                  <i class="bi bi-arrow-up-right"></i>
                </RouterLink>
              </div>

              <!-- Informasi proyek -->
              <div class="project-info">
                <div class="project-heading">
                  <h3>{{ project.title }}</h3>

                  <span
                    class="project-status-dot"
                    title="Published"
                  ></span>
                </div>

                <p class="project-description">
                  {{
                    project.summary ||
                    "Eksplorasi ide, teknologi, dan solusi digital."
                  }}
                </p>

                <!-- Tombol aksi proyek -->
                <div class="project-actions">
                  <!-- Demo / website live -->
                  <a
                    v-if="project.demo_url"
                    :href="project.demo_url"
                    class="project-btn project-btn-primary"
                    target="_blank"
                    rel="noopener noreferrer"
                    title="Buka demo proyek"
                  >
                    <i class="bi bi-display"></i>
                    <span>Demo</span>
                  </a>

                  <!-- Preview -->
                  <a
                    v-if="project.preview_url"
                    :href="project.preview_url"
                    class="project-btn project-btn-outline"
                    target="_blank"
                    rel="noopener noreferrer"
                    title="Preview proyek"
                  >
                    <i class="bi bi-eye"></i>
                    <span>Preview</span>
                  </a>

                  <!-- Repository GitHub -->
                  <a
                    v-if="project.github_url"
                    :href="project.github_url"
                    class="project-btn project-btn-outline"
                    target="_blank"
                    rel="noopener noreferrer"
                    title="Lihat repository GitHub"
                  >
                    <i class="bi bi-github"></i>
                    <span>GitHub</span>
                  </a>

                  <!-- Link tambahan -->
                  <a
                    v-if="project.other_url"
                    :href="project.other_url"
                    class="project-btn project-btn-outline project-btn-icon"
                    target="_blank"
                    rel="noopener noreferrer"
                    :title="project.other_url_label || 'Link lainnya'"
                  >
                    <i class="bi bi-link-45deg"></i>
                  </a>

                  <!-- Detail internal portfolio -->
                  <RouterLink
                    :to="{
                      name: 'project-detail',
                      params: { slug: project.slug },
                    }"
                    class="project-btn project-btn-detail"
                    :aria-label="`Lihat detail ${project.title}`"
                    title="Detail proyek"
                  >
                    <i class="bi bi-arrow-right"></i>
                  </RouterLink>
                </div>
              </div>
            </article>
          </div>
        </div>
      </section>

      <!-- CONTACT -->
      <section
        id="contact"
        class="section-block contact-section"
      >
        <div class="site-container">
          <div class="contact-panel">
            <div class="contact-orb contact-orb-one"></div>
            <div class="contact-orb contact-orb-two"></div>

            <div class="contact-content">
              <p class="section-eyebrow"><span>03</span> / LET'S CONNECT</p>

              <h2>
                Punya ide?
                <br />
                <span>Mari wujudkan.</span>
              </h2>

              <p>
                Terbuka untuk percakapan, kolaborasi, dan proyek digital yang
                punya tujuan jelas.
              </p>

              <a
                v-if="email"
                :href="`mailto:${email}`"
                class="btn-primary-custom"
              >
                Mulai percakapan
                <i class="bi bi-arrow-up-right ms-2"></i>
              </a>

              <a
                v-else
                href="#about"
                class="btn-primary-custom"
              >
                Kenali saya
                <i class="bi bi-arrow-up-right ms-2"></i>
              </a>
            </div>

            <div
              class="contact-decoration"
              aria-hidden="true"
            >
              <span>LET'S</span>
              <span>BUILD<span class="text-accent">.</span></span>
              <span>TOGETHER</span>
            </div>
          </div>
        </div>
      </section>

      <!-- CERTIFICATES -->
      <section
        id="certificates"
        class="section-block certificates-section"
      >
        <div class="site-container">
          <div class="section-heading">
            <div>
              <p class="section-eyebrow"><span>04</span> / CERTIFICATIONS</p>

              <h2 class="section-title">
                Bukti proses
                <span class="text-accent">belajar.</span>
              </h2>
            </div>

            <p class="section-side-note">
              Sertifikat dan pencapaian yang merepresentasikan proses belajar
              serta pengembangan kompetensi.
            </p>
          </div>

          <!-- Loading -->
          <div
            v-if="certificatesLoading"
            class="certificate-state"
            role="status"
          >
            <span class="spinner-border spinner-border-sm me-2"></span>
            Memuat sertifikat...
          </div>

          <!-- Error -->
          <div
            v-else-if="certificatesError"
            class="certificate-state certificate-error"
            role="alert"
          >
            <i class="bi bi-exclamation-circle me-2"></i>
            {{ certificatesError }}
          </div>

          <!-- Empty -->
          <div
            v-else-if="certificates.length === 0"
            class="certificate-empty"
          >
            <i class="bi bi-patch-check"></i>
            <h3>Sertifikat akan ditampilkan di sini</h3>
            <p>
              Sertifikat yang diaktifkan untuk ditampilkan akan muncul otomatis.
            </p>
          </div>

          <!-- Certificate cards -->

          <div
            v-else
            class="certificate-grid"
          >
            <article
              v-for="certificate in certificates"
              :key="certificate.id"
              class="certificate-card"
            >
              <!-- Thumbnail sertifikat -->
              <a
                class="certificate-image-wrap"
                :href="
                  certificate.file_url ||
                  certificate.image_url ||
                  certificate.credential_url ||
                  '#'
                "
                target="_blank"
                rel="noopener noreferrer"
                :aria-label="`Lihat sertifikat ${certificate.title}`"
              >
                <img
                  v-if="certificate.image_url"
                  :src="certificate.image_url"
                  :alt="`Thumbnail ${certificate.title}`"
                  loading="lazy"
                />

                <div
                  v-else
                  class="certificate-image-placeholder"
                >
                  <i class="bi bi-award"></i>
                  <span>Preview tidak tersedia</span>
                </div>
              </a>

              <!-- Informasi sertifikat -->
              <div class="certificate-info">
                <h3>{{ certificate.title }}</h3>

                <p
                  v-if="certificate.issuer"
                  class="certificate-issuer"
                >
                  <i class="bi bi-building"></i>
                  <span>{{ certificate.issuer }}</span>
                </p>

                <p
                  v-if="certificate.issued_at"
                  class="certificate-date"
                >
                  <i class="bi bi-calendar3"></i>
                  <span>{{
                    formatCertificateDate(certificate.issued_at)
                  }}</span>
                </p>

                <div class="certificate-actions">
                  <a
                    v-if="certificate.credential_url"
                    :href="certificate.credential_url"
                    class="certificate-link"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Verifikasi
                    <i class="bi bi-arrow-up-right"></i>
                  </a>

                  <a
                    v-if="certificate.file_url || certificate.image_url"
                    :href="certificate.file_url || certificate.image_url"
                    class="certificate-link certificate-file-link"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Buka file
                    <i class="bi bi-file-earmark-arrow-up"></i>
                  </a>
                </div>
              </div>
            </article>
          </div>
        </div>
      </section>
    </main>

    <!-- FOOTER -->
    <footer class="site-footer">
      <div class="site-container footer-inner">
        <RouterLink
          to="/"
          class="brand footer-brand"
        >
          <span class="brand-symbol">J.</span>
          <span class="brand-name">{{ displayName }}</span>
        </RouterLink>

        <p>
          © {{ currentYear }} {{ displayName }}. Dibuat dengan rasa ingin tahu.
        </p>

        <a
          href="#"
          class="back-to-top"
          aria-label="Kembali ke atas"
        >
          <i class="bi bi-arrow-up"></i>
        </a>
      </div>
    </footer>
  </div>
</template>

<style>
/* Global scope sengaja digunakan agar style komponen tersedia konsisten. */
.portfolio-home {
  --home-bg: #0b0e11;
  --home-surface: #11161b;
  --home-surface-2: #171e24;
  --home-border: rgba(255, 255, 255, 0.09);
  --home-muted: #939da6;
  --home-text: #f1f5f5;
  --home-accent: #55e6c1;

  background: var(--home-bg);
  color: var(--home-text);
  min-height: 100vh;
  overflow: hidden;
}

.portfolio-home * {
  box-sizing: border-box;
}

.portfolio-home a {
  text-decoration: none;
}

.portfolio-home .site-container {
  width: min(1180px, calc(100% - 48px));
  margin-inline: auto;
}

.portfolio-home .text-accent {
  color: var(--home-accent) !important;
}

.portfolio-home .site-header {
  position: sticky;
  top: 0;
  z-index: 1000;
  border-bottom: 1px solid rgba(255, 255, 255, 0.055);
  background: rgba(11, 14, 17, 0.82);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
}

.portfolio-home .nav-inner {
  min-height: 78px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
}

.portfolio-home .brand {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  color: var(--home-text);
  min-width: 0;
}

.portfolio-home .brand-symbol {
  display: grid;
  place-items: center;
  width: 39px;
  height: 39px;
  border-radius: 12px;
  color: #061511;
  background: var(--home-accent);
  font-size: 19px;
  font-weight: 900;
  letter-spacing: -1px;
}

.portfolio-home .brand-name {
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  overflow-wrap: anywhere;
}

.portfolio-home .brand-dot {
  color: var(--home-accent);
}

.portfolio-home .nav-links {
  display: flex;
  align-items: center;
  gap: 32px;
}

.portfolio-home .nav-links > a:not(.nav-admin) {
  color: #a9b2b8;
  font-size: 13px;
  transition: color 0.2s ease;
}

.portfolio-home .nav-links > a:not(.nav-admin):hover {
  color: var(--home-accent);
}

.portfolio-home .nav-admin {
  padding: 10px 15px;
  border: 1px solid var(--home-border);
  border-radius: 10px;
  color: var(--home-text);
  font-size: 12px;
  transition:
    border-color 0.2s,
    background 0.2s;
}

.portfolio-home .nav-admin:hover {
  border-color: var(--home-accent);
  background: rgba(85, 230, 193, 0.07);
}

.portfolio-home .mobile-toggle {
  display: none;
  width: 42px;
  height: 42px;
  color: var(--home-text);
  background: var(--home-surface);
  border: 1px solid var(--home-border);
  border-radius: 10px;
  font-size: 22px;
}

.portfolio-home .hero-section {
  /* min-height: 700px; */
  position: relative;
  display: flex;
  align-items: center;
  padding: 50px 0 36px;
  isolation: isolate;
}

.portfolio-home .hero-grid {
  position: absolute;
  inset: 0;
  z-index: -1;
  pointer-events: none;
  opacity: 0.27;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.035) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.035) 1px, transparent 1px);
  background-size: 62px 62px;
  mask-image: linear-gradient(to bottom, black, transparent 90%);
}

.portfolio-home .hero-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.08fr) minmax(350px, 0.92fr);
  align-items: center;
  gap: 60px;
}

.portfolio-home .hero-content {
  position: relative;
  z-index: 2;
  animation: homeRise 0.7s ease both;
}

.portfolio-home .availability {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 9px 13px;
  border: 1px solid rgba(85, 230, 193, 0.19);
  border-radius: 999px;
  color: #b6c2c5;
  background: rgba(85, 230, 193, 0.045);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.5px;
}

.portfolio-home .availability-dot {
  width: 7px;
  height: 7px;
  background: var(--home-accent);
  border-radius: 50%;
  box-shadow: 0 0 12px rgba(85, 230, 193, 0.6);
}

.portfolio-home .hero-kicker {
  margin: 36px 0 13px;
  color: var(--home-accent);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 3px;
}

.portfolio-home .hero-title {
  max-width: 700px;
  font-size: clamp(43px, 5.4vw, 73px);
  line-height: 1.07;
  letter-spacing: -3.7px;
  font-weight: 850;
}

.portfolio-home .hero-highlight {
  display: block;
  color: var(--home-accent);
}

.portfolio-home .hero-description {
  max-width: 530px;
  color: var(--home-muted);
  font-size: 15px;
  line-height: 1.95;
  margin: 24px 0 30px;
}

.portfolio-home .hero-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.portfolio-home .btn-primary-custom,
.portfolio-home .btn-secondary-custom {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 14px 19px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 750;
  transition:
    transform 0.2s ease,
    background 0.2s ease,
    border-color 0.2s ease;
}

.portfolio-home .btn-primary-custom {
  background: var(--home-accent);
  color: #071612;
  border: 1px solid var(--home-accent);
}

.portfolio-home .btn-primary-custom:hover {
  color: #071612;
  transform: translateY(-3px);
  box-shadow: 0 8px 30px rgba(85, 230, 193, 0.13);
}

.portfolio-home .btn-secondary-custom {
  color: var(--home-text);
  border: 1px solid var(--home-border);
  background: rgba(255, 255, 255, 0.015);
}

.portfolio-home .btn-secondary-custom:hover {
  color: var(--home-accent);
  border-color: rgba(85, 230, 193, 0.5);
  transform: translateY(-3px);
}

.portfolio-home .hero-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 18px;
  margin-top: 46px;
}

.portfolio-home .hero-meta-item {
  display: flex;
  align-items: center;
  gap: 9px;
  color: #a5afb6;
  font-size: 11px;
}

.portfolio-home .hero-meta-item i {
  color: var(--home-accent);
  font-size: 15px;
}

.portfolio-home .meta-divider {
  height: 18px;
  width: 1px;
  background: var(--home-border);
}

.portfolio-home .hero-visual {
  position: relative;
  padding: 25px 10px;
  animation: homeRise 0.9s ease 0.1s both;
}

.portfolio-home .visual-glow {
  position: absolute;
  width: 300px;
  height: 300px;
  right: 10%;
  top: 20%;
  border-radius: 50%;
  background: rgba(35, 209, 168, 0.12);
  filter: blur(85px);
  pointer-events: none;
}

.portfolio-home .visual-card {
  position: relative;
  z-index: 1;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 23px;
  background: linear-gradient(145deg, #171e24, #0e1216);
  box-shadow: 0 35px 90px rgba(0, 0, 0, 0.35);
  transform: rotate(1.2deg);
}

.portfolio-home .visual-card-top {
  height: 53px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 21px;
  border-bottom: 1px solid var(--home-border);
}

.portfolio-home .window-dots {
  display: flex;
  gap: 6px;
}

.portfolio-home .window-dots span {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #414b52;
}

.portfolio-home .window-dots span:first-child {
  background: #e38b82;
}

.portfolio-home .window-dots span:nth-child(2) {
  background: #e6c26e;
}

.portfolio-home .window-dots span:nth-child(3) {
  background: var(--home-accent);
}

.portfolio-home .visual-label {
  color: #76838a;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 2px;
}

.portfolio-home .profile-art {
  position: relative;
  display: grid;
  place-items: center;
  min-height: 325px;
  overflow: hidden;
  background:
    radial-gradient(
      ellipse at center,
      rgba(85, 230, 193, 0.11),
      transparent 60%
    ),
    linear-gradient(135deg, rgba(255, 255, 255, 0.018), transparent);
}

.portfolio-home .profile-ring {
  position: absolute;
  width: 220px;
  height: 220px;
  border: 1px solid rgba(85, 230, 193, 0.25);
  border-radius: 50%;
}

.portfolio-home .profile-avatar {
  position: relative;
  z-index: 2;
  width: 170px;
  height: 170px;
  border: 5px solid rgba(85, 230, 193, 0.14);
  border-radius: 50%;
  object-fit: cover;
  box-shadow: 0 0 60px rgba(85, 230, 193, 0.12);
}

.portfolio-home .profile-avatar-fallback {
  display: grid;
  place-items: center;
  color: #071612;
  background: linear-gradient(135deg, #7df3d4, #27b997);
  font-size: 70px;
  font-weight: 850;
}

.portfolio-home .orbit {
  position: absolute;
  width: 260px;
  height: 90px;
  border: 1px solid rgba(85, 230, 193, 0.24);
  border-radius: 50%;
}

.portfolio-home .orbit-one {
  transform: rotate(45deg);
}

.portfolio-home .orbit-two {
  transform: rotate(-45deg);
}

.portfolio-home .orbit-three {
  width: 305px;
  height: 125px;
  border-color: rgba(255, 255, 255, 0.07);
  transform: rotate(15deg);
}

.portfolio-home .floating-chip {
  position: absolute;
  z-index: 3;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 13px;
  color: #d9e2e2;
  border: 1px solid rgba(255, 255, 255, 0.11);
  border-radius: 10px;
  background: rgba(17, 22, 27, 0.92);
  backdrop-filter: blur(10px);
  font-size: 10px;
  font-weight: 650;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
}

.portfolio-home .floating-chip i {
  color: var(--home-accent);
  font-size: 14px;
}

.portfolio-home .chip-code {
  top: 50px;
  left: 14px;
}

.portfolio-home .chip-design {
  right: 10px;
  bottom: 48px;
}

.portfolio-home .visual-card-bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 15px;
  padding: 24px;
  border-top: 1px solid var(--home-border);
}

.portfolio-home .visual-eyebrow {
  color: var(--home-accent);
  font-size: 9px;
  letter-spacing: 2px;
  font-weight: 800;
  margin-bottom: 8px;
}

.portfolio-home .visual-card-bottom h2 {
  font-size: 16px;
  line-height: 1.5;
  font-weight: 750;
  margin: 0;
}

.portfolio-home .visual-arrow {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  width: 42px;
  height: 42px;
  color: var(--home-accent);
  border: 1px solid rgba(85, 230, 193, 0.25);
  border-radius: 12px;
}

.portfolio-home .floating-index {
  position: absolute;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 10px;
  color: #a4b0b5;
  font-size: 9px;
  font-weight: 750;
  letter-spacing: 2px;
}

.portfolio-home .index-number {
  color: var(--home-accent);
  font-size: 17px;
  font-weight: 850;
}

.portfolio-home .index-top {
  top: 4px;
  right: 0;
}

.portfolio-home .index-bottom {
  bottom: 5px;
  left: -12px;
}

.portfolio-home .hero-bottom {
  position: absolute;
  bottom: 28px;
  left: 50%;
  display: flex;
  justify-content: space-between;
  transform: translateX(-50%);
  color: #758189;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 2px;
}

.portfolio-home .scroll-indicator {
  display: flex;
  align-items: center;
  gap: 12px;
  color: #a7b0b5;
}

.portfolio-home .scroll-indicator i {
  color: var(--home-accent);
}

.portfolio-home .section-block {
  padding: 20px 0;
  scroll-margin-top: 85px;
}

.portfolio-home .work-section {
  border-top: 1px solid rgba(255, 255, 255, 0.045);
}

.portfolio-home .section-heading {
  display: flex;
  justify-content: space-between;
  align-items: end;
  gap: 32px;
  margin-bottom: 43px;
}

.portfolio-home .section-eyebrow {
  color: #7c898f;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 2.4px;
  margin-bottom: 18px;
}

.portfolio-home .section-eyebrow span {
  color: var(--home-accent);
}

.portfolio-home .section-title {
  max-width: 700px;
  font-size: clamp(34px, 4vw, 51px);
  line-height: 1.15;
  font-weight: 820;
  letter-spacing: -2px;
  margin: 0;
}

.portfolio-home .section-side-note {
  max-width: 320px;
  color: var(--home-muted);
  font-size: 12px;
  line-height: 1.9;
  margin: 0 0 3px;
}

/* ========================================
   PROJECT GRID
======================================== */
.portfolio-home .project-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 24px;
  align-items: stretch;
}

/* Semua kartu memiliki ukuran dan tinggi konsisten */
.portfolio-home .project-card,
.portfolio-home .project-card-featured {
  display: flex;
  flex-direction: column;
  width: 100%;
  min-width: 0;
  height: 100%;
  grid-column: auto;
  overflow: hidden;
  text-decoration: none;
}

/* ========================================
   PROJECT IMAGE
======================================== */
.portfolio-home .project-image-wrap {
  position: relative;
  width: 100%;
  aspect-ratio: 4 / 3;
  flex-shrink: 0;
  overflow: hidden;
  border-radius: 14px;
}

.portfolio-home .project-image,
.portfolio-home .project-image-placeholder {
  display: block;
  width: 100%;
  height: 100%;
}

.portfolio-home .project-image {
  object-fit: cover;
  transition: transform 0.45s ease;
}

.portfolio-home .project-card:hover .project-image {
  transform: scale(1.05);
}

.portfolio-home .project-image-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Nomor proyek */
.portfolio-home .project-number {
  position: absolute;
  top: 15px;
  left: 15px;
  z-index: 1;
}

/* Tombol panah */
.portfolio-home .project-open {
  position: absolute;
  right: 15px;
  bottom: 15px;
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  color: #071612;
  background: var(--home-accent);
  border-radius: 50%;
  opacity: 0;
  transform: translateY(5px);
  transition:
    opacity 0.25s ease,
    transform 0.25s ease;
}

.portfolio-home .project-card:hover .project-open,
.portfolio-home .project-card:focus-visible .project-open {
  opacity: 1;
  transform: translateY(0);
}

/* ========================================
   PROJECT GRID
======================================== */
.portfolio-home .project-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  align-items: stretch;
  gap: 22px;
}

.portfolio-home .project-card {
  min-width: 0;
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;

  color: inherit;
  text-decoration: none;

  background: rgba(255, 255, 255, 0.025);
  border: 1px solid rgba(255, 255, 255, 0.11);
  border-radius: 18px;

  transition:
    transform 0.3s ease,
    border-color 0.3s ease,
    background 0.3s ease,
    box-shadow 0.3s ease;
}

.portfolio-home .project-card:hover {
  transform: translateY(-5px);
  border-color: var(--home-accent);
  background: rgba(255, 255, 255, 0.045);
  box-shadow: 0 16px 40px rgba(0, 0, 0, 0.2);
}

/* ========================================
   IMAGE
======================================== */
.portfolio-home .project-image-wrap {
  position: relative;
  flex-shrink: 0;
  width: 100%;
  aspect-ratio: 4 / 3;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.04);
  border-radius: 17px 17px 0 0;
}

.portfolio-home .project-image {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.5s ease;
}

.portfolio-home .project-card:hover .project-image {
  transform: scale(1.045);
}

.portfolio-home .project-image-placeholder {
  display: grid;
  width: 100%;
  height: 100%;
  place-items: center;
  color: var(--home-accent);
  font-size: 42px;
  background: radial-gradient(
    circle at 50% 40%,
    rgba(255, 255, 255, 0.07),
    transparent 65%
  );
}

.portfolio-home .project-number {
  position: absolute;
  top: 13px;
  left: 13px;
  z-index: 1;
  padding: 6px 9px;
  color: #fff;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1px;
  background: rgba(8, 16, 14, 0.75);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 7px;
  backdrop-filter: blur(10px);
}

.portfolio-home .project-category-badge {
  position: absolute;
  right: 12px;
  bottom: 12px;
  max-width: calc(100% - 70px);
  overflow: hidden;
  padding: 7px 10px;
  color: #fff;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 1px;
  text-overflow: ellipsis;
  white-space: nowrap;
  background: rgba(8, 16, 14, 0.78);
  border: 1px solid rgba(255, 255, 255, 0.13);
  border-radius: 8px;
  backdrop-filter: blur(10px);
}

.portfolio-home .project-image-action {
  position: absolute;
  top: 50%;
  left: 50%;
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  color: #071612;
  font-size: 19px;
  text-decoration: none;
  background: var(--home-accent);
  border-radius: 50%;
  opacity: 0;
  transform: translate(-50%, -40%);
  transition: 0.25s ease;
}

.portfolio-home .project-card:hover .project-image-action,
.portfolio-home .project-image-action:focus-visible {
  opacity: 1;
  transform: translate(-50%, -50%);
}

/* ========================================
   PROJECT INFORMATION
======================================== */
.portfolio-home .project-info {
  display: flex;
  flex: 1;
  flex-direction: column;
  align-items: stretch;
  min-width: 0;
  padding: 20px;
}

.portfolio-home .project-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}

.portfolio-home .project-info h3 {
  min-width: 0;
  margin: 0 0 10px;
  font-size: 17px;
  font-weight: 750;
  line-height: 1.45;
  overflow-wrap: anywhere;
}

.portfolio-home .project-status-dot {
  flex-shrink: 0;
  width: 7px;
  height: 7px;
  margin-top: 7px;
  background: var(--home-accent);
  border-radius: 50%;
  box-shadow: 0 0 12px var(--home-accent);
}

.portfolio-home .project-description {
  flex: 1;
  margin: 0 0 20px;
  color: var(--home-muted);
  font-size: 12px;
  line-height: 1.8;

  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 3;
  overflow: hidden;
}

/* ========================================
   ACTION BUTTONS
======================================== */
.portfolio-home .project-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: auto;
  padding-top: 15px;
  border-top: 1px solid rgba(255, 255, 255, 0.09);
}

.portfolio-home .project-actions {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: auto;
  padding-top: 15px;
  border-top: 1px solid rgba(255, 255, 255, 0.09);
}

.portfolio-home .project-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  min-height: 36px;
  padding: 8px 11px;
  color: var(--home-text, #fff);
  font-size: 11px;
  font-weight: 700;
  text-decoration: none;
  white-space: nowrap;
  border: 1px solid rgba(255, 255, 255, 0.16);
  border-radius: 9px;
  transition: all 0.2s ease;
}

.portfolio-home .project-btn-primary {
  flex: 1;
  color: #071612;
  background: var(--home-accent);
  border-color: var(--home-accent);
}

.portfolio-home .project-btn-primary:hover {
  color: #071612;
  filter: brightness(1.1);
  transform: translateY(-2px);
}

.portfolio-home .project-btn-outline:hover {
  color: var(--home-accent);
  border-color: var(--home-accent);
  background: rgba(255, 255, 255, 0.04);
}

.portfolio-home .project-btn-icon {
  width: 36px;
  padding: 0;
  font-size: 16px;
}

.portfolio-home .project-btn-detail {
  flex-shrink: 0;
  width: 36px;
  padding: 0;
  color: var(--home-accent);
}

.portfolio-home .project-btn-detail:hover {
  color: #071612;
  background: var(--home-accent);
  border-color: var(--home-accent);
}

.portfolio-home .project-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  min-height: 36px;
  padding: 8px 11px;

  font-size: 11px;
  font-weight: 700;
  line-height: 1;
  text-decoration: none;
  white-space: nowrap;

  border: 1px solid transparent;
  border-radius: 9px;

  transition:
    color 0.2s ease,
    background 0.2s ease,
    border-color 0.2s ease,
    transform 0.2s ease;
}

.portfolio-home .project-btn:hover {
  transform: translateY(-2px);
}

.portfolio-home .project-btn-primary {
  flex: 1;
  color: #071612;
  background: var(--home-accent);
  border-color: var(--home-accent);
}

.portfolio-home .project-btn-primary:hover {
  color: #071612;
  filter: brightness(1.08);
}

.portfolio-home .project-btn-outline {
  flex: 1;
  color: var(--home-text, #fff);
  background: transparent;
  border-color: rgba(255, 255, 255, 0.17);
}

.portfolio-home .project-btn-outline:hover {
  color: var(--home-accent);
  border-color: var(--home-accent);
  background: rgba(255, 255, 255, 0.04);
}

.portfolio-home .project-btn-detail {
  flex-shrink: 0;
  width: 36px;
  padding: 0;
  color: var(--home-accent);
  background: transparent;
  border-color: rgba(255, 255, 255, 0.17);
}

.portfolio-home .project-btn-detail:hover {
  color: #071612;
  background: var(--home-accent);
  border-color: var(--home-accent);
}

/* ========================================
   RESPONSIVE
======================================== */
@media (max-width: 1199.98px) {
  .portfolio-home .project-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (max-width: 991.98px) {
  .portfolio-home .project-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 18px;
  }

  .portfolio-home .project-info {
    padding: 18px;
  }
}

@media (max-width: 575.98px) {
  .portfolio-home .project-grid {
    grid-template-columns: 1fr;
    gap: 18px;
  }

  .portfolio-home .project-image-wrap {
    aspect-ratio: 16 / 10;
  }

  .portfolio-home .project-info {
    padding: 18px;
  }

  .portfolio-home .project-info h3 {
    font-size: 17px;
  }

  .portfolio-home .project-image-action {
    top: 13px;
    right: 13px;
    left: auto;
    width: 38px;
    height: 38px;
    opacity: 1;
    transform: none;
  }

  .portfolio-home .project-card:hover .project-image-action {
    transform: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .portfolio-home .project-card,
  .portfolio-home .project-image,
  .portfolio-home .project-image-action,
  .portfolio-home .project-btn {
    transition: none;
  }
}

/* ==============================
   EXPERIENCE SECTION
================================ */

.experience-section {
  position: relative;
  padding-top: 20px;
  /* padding-bottom: clamp(64px, 9vw, 110px);
  overflow: hidden; */
}

.experience-section::before {
  position: absolute;
  /* top: 12%; */
  right: -180px;
  width: 380px;
  height: 380px;
  border-radius: 50%;
  background: rgba(69, 214, 197, 0.055);
  filter: blur(100px);
  pointer-events: none;
  content: "";
}

.experience-section > .site-container {
  position: relative;
  z-index: 1;
}

.experience-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 28px;
  margin-bottom: 48px;
}

.experience-header .section-title {
  margin-bottom: 0;
}

.experience-intro {
  max-width: 600px;
  margin: 18px 0 0;
  color: var(--text-muted, #9ca3af);
  font-size: 15px;
  line-height: 1.9;
}

.experience-header-icon {
  display: flex;
  width: 72px;
  height: 72px;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(69, 214, 197, 0.22);
  border-radius: 22px;
  background: rgba(69, 214, 197, 0.07);
  color: var(--accent, #45d6c5);
  font-size: 28px;
  transform: rotate(5deg);
}

.experience-state {
  padding: 40px 20px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.025);
  color: var(--text-muted, #9ca3af);
  text-align: center;
}

.experience-state .spinner-border {
  color: var(--accent, #45d6c5);
}

.experience-error {
  color: #fca5a5;
}

.experience-empty {
  padding: 56px 24px;
  border: 1px dashed rgba(255, 255, 255, 0.13);
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.018);
  text-align: center;
}

.experience-empty-icon {
  display: flex;
  width: 60px;
  height: 60px;
  align-items: center;
  justify-content: center;
  margin: 0 auto 20px;
  border: 1px solid rgba(69, 214, 197, 0.2);
  border-radius: 18px;
  background: rgba(69, 214, 197, 0.07);
  color: var(--accent, #45d6c5);
  font-size: 24px;
}

.experience-empty h3 {
  margin-bottom: 8px;
  color: var(--text-primary, #f3f4f6);
  font-size: 18px;
  font-weight: 700;
}

.experience-empty p {
  margin-bottom: 0;
  color: var(--text-muted, #9ca3af);
  font-size: 14px;
}

/* Timeline */

/* Slim experience cards */

.experience-timeline {
  padding: 20px 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.experience-item {
  display: grid;
  grid-template-columns: 34px minmax(0, 1fr);
  gap: 12px;
}

.experience-rail {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.experience-index {
  width: 32px;
  height: 32px;
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(69, 214, 197, 0.25);
  border-radius: 10px;
  background: var(--surface, #151b24);
  color: var(--accent, #45d6c5);
  font-size: 10px;
  font-weight: 700;
}

.experience-line {
  width: 1px;
  flex: 1;
  min-height: 16px;
  margin-top: 6px;
  background: rgba(69, 214, 197, 0.25);
}

.experience-item:last-child .experience-line {
  display: none;
}

.experience-card {
  min-width: 0;
  padding: 16px 20px;
  border: 1px solid rgba(255, 255, 255, 0.075);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.02);
  transition:
    border-color 0.2s ease,
    background 0.2s ease;
}

.experience-card:hover {
  border-color: rgba(69, 214, 197, 0.25);
  background: rgba(69, 214, 197, 0.025);
}

.experience-card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.experience-main {
  min-width: 0;
  flex: 1;
}

.experience-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 8px;
}

.experience-current,
.experience-type {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 7px;
  border-radius: 5px;
  font-size: 10px;
  font-weight: 600;
  line-height: 1.4;
}

.experience-current {
  color: var(--accent, #45d6c5);
  background: rgba(69, 214, 197, 0.08);
}

.current-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: currentColor;
}

.experience-type {
  color: var(--text-muted, #9ca3af);
  background: rgba(255, 255, 255, 0.05);
}

/* Role + Organization + Location */

.experience-info-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  column-gap: 10px;
  row-gap: 5px;
}

.experience-role {
  margin: 0;
  color: var(--text-primary, #f3f4f6);
  font-size: 15px;
  font-weight: 700;
  line-height: 1.5;
}

.experience-info-separator {
  width: 3px;
  height: 3px;
  flex-shrink: 0;
  border-radius: 50%;
  background: rgba(69, 214, 197, 0.65);
}

.experience-organization,
.experience-location {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  color: var(--text-muted, #a1a1aa);
  font-size: 12px;
  line-height: 1.6;
  overflow-wrap: anywhere;
}

.experience-organization i,
.experience-location i {
  flex-shrink: 0;
  color: var(--accent, #45d6c5);
  font-size: 12px;
}

/* Date period */

.experience-period {
  display: inline-flex;
  flex-shrink: 0;
  align-items: center;
  gap: 6px;
  padding: 6px 9px;
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 8px;
  color: var(--text-muted, #9ca3af);
  font-size: 10px;
  white-space: nowrap;
}

.experience-period i {
  color: var(--accent, #45d6c5);
}

/* Description */

.experience-description {
  margin: 10px 0 0;
  padding-top: 10px;
  border-top: 1px solid rgba(255, 255, 255, 0.055);
  color: var(--text-secondary, #c1c7d0);
  font-size: 12px;
  line-height: 1.75;
  white-space: pre-line;
  overflow-wrap: anywhere;
}

/* Responsive */

@media (max-width: 768px) {
  .experience-card-top {
    align-items: flex-start;
    flex-direction: column;
    gap: 10px;
  }

  .experience-period {
    align-self: flex-start;
  }
}

@media (max-width: 480px) {
  .experience-item {
    grid-template-columns: 28px minmax(0, 1fr);
    gap: 8px;
  }

  .experience-index {
    width: 27px;
    height: 27px;
    font-size: 9px;
  }

  .experience-card {
    padding: 13px;
  }

  .experience-info-row {
    column-gap: 7px;
    row-gap: 4px;
  }

  .experience-role {
    width: 100%;
    font-size: 14px;
  }

  .experience-organization,
  .experience-location {
    font-size: 11px;
  }

  .experience-period {
    font-size: 10px;
  }

  .experience-description {
    font-size: 11px;
  }
}

/* ========================================
   CERTIFICATES SECTION
======================================== */

.portfolio-home .certificates-section {
  border-top: 1px solid rgba(255, 255, 255, 0.045);
}

.portfolio-home .certificate-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1.5rem;
  align-items: stretch;
}

.certificate-card {
  display: flex;
  flex-direction: column;
  min-width: 0;
  height: 100%;
  overflow: hidden;
  border: 1px solid var(--border-color, rgba(255, 255, 255, 0.1));
  border-radius: 16px;
  background: var(--card-bg, rgba(255, 255, 255, 0.035));
  transition:
    transform 0.25s ease,
    border-color 0.25s ease,
    box-shadow 0.25s ease;
}

.certificate-card:hover {
  transform: translateY(-4px);
  border-color: var(--accent-color, #20c9b0);
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.12);
}

.certificate-image-wrap {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  aspect-ratio: 4 / 3;
  overflow: hidden;
  background: rgba(128, 128, 128, 0.08);
  text-decoration: none;
}

.certificate-image-wrap > img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
  padding: 0.75rem;
  transition: transform 0.3s ease;
}

.certificate-card:hover .certificate-image-wrap > img {
  transform: scale(1.035);
}

.certificate-image-placeholder {
  flex-direction: column;
  gap: 0.5rem;
  color: var(--text-muted, #9ca3af);
}

.certificate-image-placeholder > i {
  font-size: 2.75rem;
}

.certificate-image-placeholder > span {
  font-size: 0.8rem;
}

.certificate-preview-action {
  position: absolute;
  right: 0.75rem;
  bottom: 0.75rem;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.7rem;
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 8px;
  background: rgba(15, 23, 42, 0.88);
  color: #fff;
  font-size: 0.75rem;
  opacity: 0;
  transform: translateY(4px);
  transition: 0.2s ease;
}

.certificate-card:hover .certificate-preview-action,
.certificate-image-wrap:focus-visible .certificate-preview-action {
  opacity: 1;
  transform: translateY(0);
}

.certificate-info {
  display: flex;
  flex: 1;
  flex-direction: column;
  padding: 1.1rem;
}

.certificate-info h3 {
  display: -webkit-box;
  min-height: 2.8em;
  margin: 0 0 0.85rem;
  overflow: hidden;
  color: var(--heading-color, inherit);
  font-size: 1rem;
  font-weight: 600;
  line-height: 1.4;
  overflow-wrap: anywhere;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.certificate-issuer,
.certificate-date {
  display: flex;
  align-items: flex-start;
  gap: 0.6rem;
  margin: 0 0 0.65rem;
  color: var(--text-muted, #9ca3af);
  font-size: 0.85rem;
  line-height: 1.5;
}

.certificate-issuer > i,
.certificate-date > i {
  flex: 0 0 auto;
  margin-top: 0.15rem;
}

.certificate-issuer span {
  overflow-wrap: anywhere;
}

.certificate-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
  margin-top: auto;
  padding-top: 1rem;
}

.certificate-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  padding: 0.55rem 0.75rem;
  border: 1px solid var(--accent-color, #20c9b0);
  border-radius: 8px;
  color: var(--accent-color, #20c9b0);
  font-size: 0.8rem;
  font-weight: 500;
  text-decoration: none;
  transition:
    background-color 0.2s ease,
    color 0.2s ease;
}

.certificate-link:hover {
  background: var(--accent-color, #20c9b0);
  color: #071b19;
}

@media (max-width: 991.98px) {
  .certificate-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1.25rem;
  }
}

@media (max-width: 575.98px) {
  .certificate-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  .certificate-card {
    border-radius: 12px;
  }

  .certificate-info {
    padding: 1rem;
  }

  .certificate-preview-action {
    opacity: 1;
    transform: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .certificate-card,
  .certificate-image-wrap > img,
  .certificate-preview-action,
  .certificate-link {
    transition: none;
  }

  .certificate-card:hover {
    transform: none;
  }
}

/* ========================================
   ABOUT SECTION
======================================== */
.portfolio-home .about-section {
  padding-top: 20px;
}

.portfolio-home .about-panel {
  position: relative;
  overflow: hidden;
  padding: 55px;
  border: 1px solid var(--home-border);
  border-radius: 23px;
  background:
    radial-gradient(
      ellipse at top right,
      rgba(85, 230, 193, 0.055),
      transparent 40%
    ),
    var(--home-surface);
}

.portfolio-home .about-decoration {
  position: absolute;
  top: -65px;
  right: 35px;
  color: rgba(85, 230, 193, 0.06);
  font-family: Georgia, serif;
  font-size: 300px;
  line-height: 1;
  pointer-events: none;
}

.portfolio-home .about-heading {
  position: relative;
  z-index: 1;
}

.portfolio-home .about-content {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: 0.75fr 1.25fr;
  gap: 60px;
  padding-top: 32px;
  border-top: 1px solid var(--home-border);
}

.portfolio-home .about-identity {
  padding: 25px;
  border: 1px solid var(--home-border);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.015);
}

.portfolio-home .about-avatar {
  display: grid;
  place-items: center;
  width: 76px;
  height: 76px;
  overflow: hidden;
  margin-bottom: 20px;
  border-radius: 20px;
  color: #071612;
  background: var(--home-accent);
  font-size: 31px;
  font-weight: 850;
}

.portfolio-home .about-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.portfolio-home .about-identity h3 {
  font-size: 18px;
  font-weight: 800;
  overflow-wrap: anywhere;
}

.portfolio-home .about-identity > p {
  color: var(--home-muted);
  font-size: 12px;
  line-height: 1.8;
}

.portfolio-home .about-location {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #a9b3b8;
  font-size: 11px;
  margin-top: 20px;
}

.portfolio-home .about-location i {
  color: var(--home-accent);
}

.portfolio-home .about-copy > p {
  color: #aab4ba;
  font-size: 13px;
  line-height: 2;
  margin-bottom: 19px;
}

.portfolio-home .about-values {
  display: grid;
  gap: 18px;
  margin-top: 28px;
}

.portfolio-home .value-item {
  display: flex;
  align-items: start;
  gap: 15px;
}

.portfolio-home .value-icon {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  width: 42px;
  height: 42px;
  color: var(--home-accent);
  border: 1px solid rgba(85, 230, 193, 0.15);
  border-radius: 12px;
  background: rgba(85, 230, 193, 0.05);
}

.portfolio-home .value-item h4 {
  font-size: 13px;
  font-weight: 750;
  margin: 2px 0 6px;
}

.portfolio-home .value-item p {
  color: var(--home-muted);
  font-size: 11px;
  line-height: 1.7;
  margin: 0;
}

.portfolio-home .contact-section {
  padding-top: 10px;
  padding-bottom: 100px;
}

.portfolio-home .contact-panel {
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 45px;
  min-height: 390px;
  padding: 60px;
  border: 1px solid rgba(85, 230, 193, 0.2);
  border-radius: 24px;
  background:
    linear-gradient(110deg, rgba(85, 230, 193, 0.07), transparent 60%), #10161a;
}

.portfolio-home .contact-content {
  position: relative;
  z-index: 2;
  max-width: 600px;
}

.portfolio-home .contact-content h2 {
  font-size: clamp(42px, 5vw, 66px);
  font-weight: 850;
  letter-spacing: -3px;
  line-height: 1.1;
  margin-bottom: 23px;
}

.portfolio-home .contact-content h2 span {
  color: var(--home-accent);
}

.portfolio-home .contact-content > p:not(.section-eyebrow) {
  max-width: 440px;
  color: var(--home-muted);
  font-size: 13px;
  line-height: 1.9;
  margin-bottom: 28px;
}

.portfolio-home .contact-decoration {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  color: rgba(255, 255, 255, 0.045);
  font-size: clamp(30px, 4vw, 58px);
  line-height: 1.1;
  font-weight: 900;
  letter-spacing: -2px;
  text-align: right;
  white-space: nowrap;
  transform: rotate(-7deg);
}

.portfolio-home .contact-orb {
  position: absolute;
  width: 250px;
  height: 250px;
  border-radius: 50%;
  filter: blur(70px);
  pointer-events: none;
}

.portfolio-home .contact-orb-one {
  top: -130px;
  right: 15%;
  background: rgba(85, 230, 193, 0.14);
}

.portfolio-home .contact-orb-two {
  bottom: -180px;
  left: 20%;
  background: rgba(47, 142, 211, 0.08);
}

.portfolio-home .site-footer {
  border-top: 1px solid var(--home-border);
}

.portfolio-home .footer-inner {
  min-height: 100px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 25px;
}

.portfolio-home .footer-brand .brand-symbol {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  font-size: 16px;
}

.portfolio-home .footer-brand .brand-name {
  font-size: 11px;
  letter-spacing: 0.5px;
}

.portfolio-home .footer-inner > p {
  color: #77838a;
  font-size: 11px;
  text-align: center;
  margin: 0;
}

.portfolio-home .back-to-top {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  color: var(--home-accent);
  border: 1px solid var(--home-border);
  border-radius: 11px;
  transition: background 0.2s;
}

.portfolio-home .back-to-top:hover {
  background: rgba(85, 230, 193, 0.08);
}

@keyframes homeRise {
  from {
    opacity: 0;
    transform: translateY(18px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@media (max-width: 991.98px) {
  .portfolio-home .hero-section {
    /* padding-top: 75px; */
    /* padding-bottom: 95px; */
  }

  .portfolio-home .hero-layout {
    grid-template-columns: 1fr;
    gap: 48px;
  }

  .portfolio-home .hero-content {
    max-width: 720px;
  }

  .portfolio-home .hero-visual {
    width: min(100%, 500px);
    margin-inline: auto;
  }

  .portfolio-home .hero-title {
    max-width: 680px;
  }

  .portfolio-home .hero-bottom {
    bottom: 25px;
  }

  .portfolio-home .section-block {
    padding: 85px 0;
  }

  .portfolio-home .about-content {
    grid-template-columns: 1fr;
    gap: 30px;
  }

  .portfolio-home .about-identity {
    display: grid;
    grid-template-columns: auto 1fr;
    column-gap: 20px;
    align-items: center;
  }

  .portfolio-home .about-avatar {
    grid-row: span 3;
    margin-bottom: 0;
  }

  .portfolio-home .about-identity h3,
  .portfolio-home .about-identity > p {
    margin-bottom: 5px;
  }

  .portfolio-home .about-location {
    margin-top: 0;
  }

  .portfolio-home .contact-decoration {
    position: absolute;
    right: 35px;
    opacity: 0.7;
  }
}

@media (max-width: 767.98px) {
  .portfolio-home .site-container {
    width: min(100% - 34px, 600px);
  }

  .portfolio-home .nav-inner {
    min-height: 68px;
  }

  .portfolio-home .mobile-toggle {
    display: grid;
    place-items: center;
  }

  .portfolio-home .nav-links {
    position: absolute;
    top: calc(100% + 1px);
    left: 0;
    right: 0;
    display: none;
    align-items: stretch;
    gap: 0;
    padding: 12px 17px 18px;
    border-bottom: 1px solid var(--home-border);
    background: #0e1216;
  }

  .portfolio-home .nav-links.nav-links-open {
    display: flex;
    flex-direction: column;
  }

  .portfolio-home .nav-links > a:not(.nav-admin) {
    padding: 14px 4px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.055);
  }

  .portfolio-home .nav-admin {
    margin-top: 12px;
    text-align: center;
  }

  .portfolio-home .hero-section {
    min-height: auto;
    padding-top: 72px;
    padding-bottom: 100px;
  }

  .portfolio-home .hero-title {
    font-size: clamp(43px, 11vw, 62px);
    letter-spacing: -2.6px;
  }

  .portfolio-home .hero-kicker {
    margin-top: 29px;
  }

  .portfolio-home .hero-description {
    font-size: 13px;
  }

  .portfolio-home .hero-meta {
    margin-top: 30px;
    gap: 12px;
  }

  .portfolio-home .hero-meta-item {
    font-size: 10px;
  }

  .portfolio-home .hero-visual {
    padding-inline: 0;
  }

  .portfolio-home .profile-art {
    min-height: 275px;
  }

  .portfolio-home .profile-avatar {
    width: 145px;
    height: 145px;
  }

  .portfolio-home .profile-ring {
    width: 190px;
    height: 190px;
  }

  .portfolio-home .orbit {
    width: 230px;
    height: 80px;
  }

  .portfolio-home .orbit-three {
    width: 260px;
    height: 110px;
  }

  .portfolio-home .chip-code {
    left: 7px;
  }

  .portfolio-home .chip-design {
    right: 5px;
  }

  .portfolio-home .floating-chip {
    padding: 8px 10px;
    font-size: 9px;
  }

  .portfolio-home .visual-card-bottom {
    padding: 19px;
  }

  .portfolio-home .visual-card-bottom h2 {
    font-size: 14px;
  }

  .portfolio-home .hero-bottom {
    bottom: 27px;
    font-size: 8px;
    letter-spacing: 1px;
  }

  .portfolio-home .section-block {
    padding: 75px 0;
  }

  .portfolio-home .section-heading {
    align-items: start;
    flex-direction: column;
    gap: 17px;
    margin-bottom: 30px;
  }

  .portfolio-home .section-title {
    font-size: clamp(34px, 8vw, 45px);
    letter-spacing: -1.7px;
  }

  .portfolio-home .section-side-note {
    max-width: 460px;
  }

  .portfolio-home .project-grid {
    grid-template-columns: 1fr;
    gap: 19px;
  }

  .portfolio-home .project-card-featured {
    grid-column: auto;
    display: block;
  }

  .portfolio-home .project-card-featured .project-image-wrap {
    min-height: 0;
    aspect-ratio: 16 / 9;
  }

  .portfolio-home .project-card-featured .project-info {
    padding: 23px;
  }

  .portfolio-home .project-info {
    padding: 23px;
  }

  .portfolio-home .project-open {
    opacity: 1;
    transform: none;
  }

  .portfolio-home .about-panel {
    padding: 28px 21px;
    border-radius: 18px;
  }

  .portfolio-home .about-decoration {
    top: -30px;
    right: 0;
    font-size: 190px;
  }

  .portfolio-home .about-content {
    padding-top: 25px;
  }

  .portfolio-home .about-identity {
    padding: 17px;
  }

  .portfolio-home .contact-section {
    padding-bottom: 70px;
  }

  .portfolio-home .contact-panel {
    min-height: 0;
    padding: 36px 25px;
    border-radius: 19px;
  }

  .portfolio-home .contact-content h2 {
    font-size: clamp(42px, 10vw, 55px);
    letter-spacing: -2px;
  }

  .portfolio-home .contact-decoration {
    right: 10px;
    bottom: 20px;
    font-size: 30px;
    opacity: 0.45;
  }

  .portfolio-home .footer-inner {
    padding-block: 24px;
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 18px;
  }

  .portfolio-home .footer-inner > p {
    grid-row: 2;
    grid-column: 1 / -1;
    text-align: left;
    line-height: 1.7;
  }
}

@media (max-width: 390px) {
  .portfolio-home .hero-actions {
    align-items: stretch;
    flex-direction: column;
  }

  .portfolio-home .hero-actions a {
    width: 100%;
  }

  .portfolio-home .meta-divider {
    display: none;
  }

  .portfolio-home .hero-bottom {
    gap: 10px;
  }

  .portfolio-home .hero-bottom > span {
    max-width: 45%;
  }

  .portfolio-home .scroll-indicator {
    gap: 5px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .portfolio-home *,
  .portfolio-home *::before,
  .portfolio-home *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
</style>
