import SwiftUI

// MARK: - Main Dashboard View
struct MainDashboardView: View {
    @ObservedObject var templateManager: TemplateManager
    @Binding var selectedTemplate: TipTemplate?
    @Binding var showOnboarding: Bool
    
    @State private var searchText = ""
    @State private var showingFilterOptions = false
    @State private var filterRole: String?
    
    var filteredTemplates: [TipTemplate] {
        templateManager.templates.filter { template in
            (searchText.isEmpty || 
             template.name.localizedCaseInsensitiveContains(searchText) ||
             template.participants.contains { $0.name.localizedCaseInsensitiveContains(searchText) }) &&
            (filterRole == nil || template.participants.contains { $0.role == filterRole })
        }
    }
    
    var body: some View {
        VStack {
            if templateManager.templates.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle("WhipTip")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showOnboarding = true
                }) {
                    Image(systemName: "plus")
                }
            }
            
            if !templateManager.templates.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFilterOptions = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search templates")
        .actionSheet(isPresented: $showingFilterOptions) {
            ActionSheet(
                title: Text("Filter Templates"),
                message: Text("Select a role to filter by"),
                buttons: filterButtons
            )
        }
    }
    
    var filterButtons: [ActionSheet.Button] {
        var buttons = [ActionSheet.Button]()
        
        let roles = Set(templateManager.templates.flatMap { $0.participants }.map { $0.role })
        for role in roles.sorted() {
            buttons.append(.default(Text(role)) {
                filterRole = role
            })
        }
        
        if filterRole != nil {
            buttons.append(.destructive(Text("Clear Filter")) {
                filterRole = nil
            })
        }
        
        buttons.append(.cancel())
        return buttons
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("No Templates Yet")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Create your first tip splitting template to get started")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            PrimaryButton(title: "Create Template") {
                showOnboarding = true
            }
            .padding(.horizontal, 40)
            .padding(.top)
        }
    }
    
    var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !filteredTemplates.isEmpty {
                    ForEach(filteredTemplates) { template in
                        TemplateCardView(template: template)
                            .onTapGesture {
                                selectedTemplate = template
                            }
                    }
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No matching templates")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        if filterRole != nil {
                            Text("Try removing the '\(filterRole!)' filter")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Try searching with different keywords")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 50)
                }
            }
            .padding()
        }
    }
    
    struct TemplateCardView: View {
        let template: TipTemplate
        
        var body: some View {
            NavigationLink(destination: TemplateDetailView(template: template, templateManager: TemplateManager.shared)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(template.rules.type.rawValue.capitalized)
                            .font(.caption)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    HStack {
                        ForEach(template.participants.prefix(4)) { participant in
                            Text(participant.emoji)
                                .font(.title3)
                                .frame(width: 30, height: 30)
                                .background(participant.color.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        if template.participants.count > 4 {
                            Text("+\(template.participants.count - 4)")
                                .font(.caption)
                                .frame(width: 30, height: 30)
                                .background(Color(.systemGray4))
                                .clipShape(Circle())
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("\(template.participants.count) staff")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}