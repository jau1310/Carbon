// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//  
//    http://www.apache.org/licenses/LICENSE-2.0
//   
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Carbon.Security
{
	public sealed class ComAccessRule : AccessRule
	{
		public ComAccessRule(IdentityReference identity, ComAccessRights rights, AccessControlType type) 
			: base(identity, (int)rights, false, InheritanceFlags.None, PropagationFlags.None, type)
		{
			if( (rights & ComAccessRights.Execute) == 0 )
			{
				throw new ArgumentException("COM access rights must always have the Execute bit set.", "rights");
			}
			ComAccessRights = rights;
		}

		public ComAccessRights ComAccessRights { get; private set; }

		public override bool Equals(object obj)
		{
			var rule = obj as ComAccessRule;

			if (rule == null)
			{
				return false;
			}

			return rule.ComAccessRights == ComAccessRights && 
			       rule.IdentityReference == IdentityReference &&
			       rule.AccessControlType == AccessControlType;
		}

        public override int GetHashCode()
        {
            // http://stackoverflow.com/questions/263400/what-is-the-best-algorithm-for-an-overridden-system-object-gethashcode
            unchecked // Overflow is fine, just wrap
            {
                var hash = 17;
                // Suitable nullity checks etc, of course :)
                hash = hash * 23 + ComAccessRights.GetHashCode();
                hash = hash * 23 + IdentityReference.GetHashCode();
                hash = hash * 23 + AccessControlType.GetHashCode();
                return hash;
            }
        }
	}
}

